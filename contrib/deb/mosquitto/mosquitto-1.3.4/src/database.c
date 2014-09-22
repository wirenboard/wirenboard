/*
Copyright (c) 2009-2013 Roger Light <roger@atchoo.org>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of mosquitto nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
*/

#include <assert.h>
#include <stdio.h>

#include <config.h>

#include <mosquitto_broker.h>
#include <memory_mosq.h>
#include <send_mosq.h>
#include <time_mosq.h>

static int max_inflight = 20;
static int max_queued = 100;
#ifdef WITH_SYS_TREE
extern unsigned long g_msgs_dropped;
#endif

int mqtt3_db_open(struct mqtt3_config *config, struct mosquitto_db *db)
{
	int rc = 0;
	struct _mosquitto_subhier *child;

	if(!config || !db) return MOSQ_ERR_INVAL;

	db->last_db_id = 0;

	db->context_count = 1;
	db->contexts = _mosquitto_malloc(sizeof(struct mosquitto*)*db->context_count);
	if(!db->contexts) return MOSQ_ERR_NOMEM;
	db->contexts[0] = NULL;
	// Initialize the hashtable
	db->clientid_index_hash = NULL;

	db->subs.next = NULL;
	db->subs.subs = NULL;
	db->subs.topic = "";

	child = _mosquitto_malloc(sizeof(struct _mosquitto_subhier));
	if(!child){
		_mosquitto_log_printf(NULL, MOSQ_LOG_ERR, "Error: Out of memory.");
		return MOSQ_ERR_NOMEM;
	}
	child->next = NULL;
	child->topic = _mosquitto_strdup("");
	if(!child->topic){
		_mosquitto_log_printf(NULL, MOSQ_LOG_ERR, "Error: Out of memory.");
		return MOSQ_ERR_NOMEM;
	}
	child->subs = NULL;
	child->children = NULL;
	child->retained = NULL;
	db->subs.children = child;

	child = _mosquitto_malloc(sizeof(struct _mosquitto_subhier));
	if(!child){
		_mosquitto_log_printf(NULL, MOSQ_LOG_ERR, "Error: Out of memory.");
		return MOSQ_ERR_NOMEM;
	}
	child->next = NULL;
	child->topic = _mosquitto_strdup("$SYS");
	if(!child->topic){
		_mosquitto_log_printf(NULL, MOSQ_LOG_ERR, "Error: Out of memory.");
		return MOSQ_ERR_NOMEM;
	}
	child->subs = NULL;
	child->children = NULL;
	child->retained = NULL;
	db->subs.children->next = child;

	db->unpwd = NULL;

#ifdef WITH_PERSISTENCE
	if(config->persistence && config->persistence_filepath){
		if(mqtt3_db_restore(db)) return 1;
	}
#endif

	return rc;
}

static void subhier_clean(struct _mosquitto_subhier *subhier)
{
	struct _mosquitto_subhier *next;
	struct _mosquitto_subleaf *leaf, *nextleaf;

	while(subhier){
		next = subhier->next;
		leaf = subhier->subs;
		while(leaf){
			nextleaf = leaf->next;
			_mosquitto_free(leaf);
			leaf = nextleaf;
		}
		if(subhier->retained){
			subhier->retained->ref_count--;
		}
		subhier_clean(subhier->children);
		if(subhier->topic) _mosquitto_free(subhier->topic);

		_mosquitto_free(subhier);
		subhier = next;
	}
}

int mqtt3_db_close(struct mosquitto_db *db)
{
	subhier_clean(db->subs.children);
	mqtt3_db_store_clean(db);

	return MOSQ_ERR_SUCCESS;
}

/* Returns the number of client currently in the database.
 * This includes inactive clients.
 * Returns 1 on failure (count is NULL)
 * Returns 0 on success.
 */
int mqtt3_db_client_count(struct mosquitto_db *db, unsigned int *count, unsigned int *inactive_count)
{
	int i;

	if(!db || !count || !inactive_count) return MOSQ_ERR_INVAL;

	*count = 0;
	*inactive_count = 0;
	for(i=0; i<db->context_count; i++){
		if(db->contexts[i]){
			(*count)++;
			if(db->contexts[i]->sock == INVALID_SOCKET){
				(*inactive_count)++;
			}
		}
	}

	return MOSQ_ERR_SUCCESS;
}

static void _message_remove(struct mosquitto *context, struct mosquitto_client_msg **msg, struct mosquitto_client_msg *last)
{
	if(!context || !msg || !(*msg)){
		return;
	}

	/* FIXME - it would be nice to be able to remove the stored message here if ref_count==0 */
	(*msg)->store->ref_count--;
	if(last){
		last->next = (*msg)->next;
		if(!last->next){
			context->last_msg = last;
		}
	}else{
		context->msgs = (*msg)->next;
		if(!context->msgs){
			context->last_msg = NULL;
		}
	}
	context->msg_count--;
	if((*msg)->qos > 0){
		context->msg_count12--;
	}
	_mosquitto_free(*msg);
	if(last){
		*msg = last->next;
	}else{
		*msg = context->msgs;
	}
}

int mqtt3_db_message_delete(struct mosquitto *context, uint16_t mid, enum mosquitto_msg_direction dir)
{
	struct mosquitto_client_msg *tail, *last = NULL;
	int msg_index = 0;
	bool deleted = false;

	if(!context) return MOSQ_ERR_INVAL;

	tail = context->msgs;
	while(tail){
		msg_index++;
		if(tail->state == mosq_ms_queued && msg_index <= max_inflight){
			tail->timestamp = mosquitto_time();
			if(tail->direction == mosq_md_out){
				switch(tail->qos){
					case 0:
						tail->state = mosq_ms_publish_qos0;
						break;
					case 1:
						tail->state = mosq_ms_publish_qos1;
						break;
					case 2:
						tail->state = mosq_ms_publish_qos2;
						break;
				}
			}else{
				if(tail->qos == 2){
					tail->state = mosq_ms_wait_for_pubrel;
				}
			}
		}
		if(tail->mid == mid && tail->direction == dir){
			msg_index--;
			_message_remove(context, &tail, last);
			deleted = true;
		}else{
			last = tail;
			tail = tail->next;
		}
		if(msg_index > max_inflight && deleted){
			return MOSQ_ERR_SUCCESS;
		}
	}

	return MOSQ_ERR_SUCCESS;
}

int mqtt3_db_message_insert(struct mosquitto_db *db, struct mosquitto *context, uint16_t mid, enum mosquitto_msg_direction dir, int qos, bool retain, struct mosquitto_msg_store *stored)
{
	struct mosquitto_client_msg *msg;
	enum mosquitto_msg_state state = mosq_ms_invalid;
	int rc = 0;
	int i;
	char **dest_ids;

	assert(stored);
	if(!context) return MOSQ_ERR_INVAL;

	/* Check whether we've already sent this message to this client
	 * for outgoing messages only.
	 * If retain==true then this is a stale retained message and so should be
	 * sent regardless. FIXME - this does mean retained messages will received
	 * multiple times for overlapping subscriptions, although this is only the
	 * case for SUBSCRIPTION with multiple subs in so is a minor concern.
	 */
	if(db->config->allow_duplicate_messages == false
			&& dir == mosq_md_out && retain == false && stored->dest_ids){

		for(i=0; i<stored->dest_id_count; i++){
			if(!strcmp(stored->dest_ids[i], context->id)){
				/* We have already sent this message to this client. */
				return MOSQ_ERR_SUCCESS;
			}
		}
	}
	if(context->sock == INVALID_SOCKET){
		/* Client is not connected only queue messages with QoS>0. */
		if(qos == 0 && !db->config->queue_qos0_messages){
			if(!context->bridge){
				return 2;
			}else{
				if(context->bridge->start_type != bst_lazy){
					return 2;
				}
			}
		}
	}

	if(context->sock != INVALID_SOCKET){
		if(qos == 0 || max_inflight == 0 || context->msg_count12 < max_inflight){
			if(dir == mosq_md_out){
				switch(qos){
					case 0:
						state = mosq_ms_publish_qos0;
						break;
					case 1:
						state = mosq_ms_publish_qos1;
						break;
					case 2:
						state = mosq_ms_publish_qos2;
						break;
				}
			}else{
				if(qos == 2){
					state = mosq_ms_wait_for_pubrel;
				}else{
					return 1;
				}
			}
		}else if(max_queued == 0 || context->msg_count12-max_inflight < max_queued){
			state = mosq_ms_queued;
			rc = 2;
		}else{
			/* Dropping message due to full queue. */
			if(context->is_dropping == false){
				context->is_dropping = true;
				_mosquitto_log_printf(NULL, MOSQ_LOG_NOTICE,
						"Outgoing messages are being dropped for client %s.",
						context->id);
			}
#ifdef WITH_SYS_TREE
			g_msgs_dropped++;
#endif
			return 2;
		}
	}else{
		if(max_queued > 0 && context->msg_count12 >= max_queued){
#ifdef WITH_SYS_TREE
			g_msgs_dropped++;
#endif
			if(context->is_dropping == false){
				context->is_dropping = true;
				_mosquitto_log_printf(NULL, MOSQ_LOG_NOTICE,
						"Outgoing messages are being dropped for client %s.",
						context->id);
			}
			return 2;
		}else{
			state = mosq_ms_queued;
		}
	}
	assert(state != mosq_ms_invalid);

#ifdef WITH_PERSISTENCE
	if(state == mosq_ms_queued){
		db->persistence_changes++;
	}
#endif

	msg = _mosquitto_malloc(sizeof(struct mosquitto_client_msg));
	if(!msg) return MOSQ_ERR_NOMEM;
	msg->next = NULL;
	msg->store = stored;
	msg->store->ref_count++;
	msg->mid = mid;
	msg->timestamp = mosquitto_time();
	msg->direction = dir;
	msg->state = state;
	msg->dup = false;
	msg->qos = qos;
	msg->retain = retain;
	if(context->last_msg){
		context->last_msg->next = msg;
		context->last_msg = msg;
	}else{
		context->msgs = msg;
		context->last_msg = msg;
	}
	context->msg_count++;
	if(qos > 0){
		context->msg_count12++;
	}

	if(db->config->allow_duplicate_messages == false && dir == mosq_md_out && retain == false){
		/* Record which client ids this message has been sent to so we can avoid duplicates.
		 * Outgoing messages only.
		 * If retain==true then this is a stale retained message and so should be
		 * sent regardless. FIXME - this does mean retained messages will received
		 * multiple times for overlapping subscriptions, although this is only the
		 * case for SUBSCRIPTION with multiple subs in so is a minor concern.
		 */
		dest_ids = _mosquitto_realloc(stored->dest_ids, sizeof(char *)*(stored->dest_id_count+1));
		if(dest_ids){
			stored->dest_ids = dest_ids;
			stored->dest_id_count++;
			stored->dest_ids[stored->dest_id_count-1] = _mosquitto_strdup(context->id);
			if(!stored->dest_ids[stored->dest_id_count-1]){
				return MOSQ_ERR_NOMEM;
			}
		}else{
			return MOSQ_ERR_NOMEM;
		}
	}
#ifdef WITH_BRIDGE
	if(context->bridge && context->bridge->start_type == bst_lazy
			&& context->sock == INVALID_SOCKET
			&& context->msg_count >= context->bridge->threshold){

		context->bridge->lazy_reconnect = true;
	}
#endif

	return rc;
}

int mqtt3_db_message_update(struct mosquitto *context, uint16_t mid, enum mosquitto_msg_direction dir, enum mosquitto_msg_state state)
{
	struct mosquitto_client_msg *tail;

	tail = context->msgs;
	while(tail){
		if(tail->mid == mid && tail->direction == dir){
			tail->state = state;
			tail->timestamp = mosquitto_time();
			return MOSQ_ERR_SUCCESS;
		}
		tail = tail->next;
	}
	return 1;
}

int mqtt3_db_messages_delete(struct mosquitto *context)
{
	struct mosquitto_client_msg *tail, *next;

	if(!context) return MOSQ_ERR_INVAL;

	tail = context->msgs;
	while(tail){
		/* FIXME - it would be nice to be able to remove the stored message here if rec_count==0 */
		tail->store->ref_count--;
		next = tail->next;
		_mosquitto_free(tail);
		tail = next;
	}
	context->msgs = NULL;
	context->last_msg = NULL;
	context->msg_count = 0;
	context->msg_count12 = 0;

	return MOSQ_ERR_SUCCESS;
}

int mqtt3_db_messages_easy_queue(struct mosquitto_db *db, struct mosquitto *context, const char *topic, int qos, uint32_t payloadlen, const void *payload, int retain)
{
	struct mosquitto_msg_store *stored;
	char *source_id;

	assert(db);

	if(!topic) return MOSQ_ERR_INVAL;

	if(context){
		source_id = context->id;
	}else{
		source_id = "";
	}
	if(mqtt3_db_message_store(db, source_id, 0, topic, qos, payloadlen, payload, retain, &stored, 0)) return 1;

	return mqtt3_db_messages_queue(db, source_id, topic, qos, retain, stored);
}

int mqtt3_db_message_store(struct mosquitto_db *db, const char *source, uint16_t source_mid, const char *topic, int qos, uint32_t payloadlen, const void *payload, int retain, struct mosquitto_msg_store **stored, dbid_t store_id)
{
	struct mosquitto_msg_store *temp;

	assert(db);
	assert(stored);

	temp = _mosquitto_malloc(sizeof(struct mosquitto_msg_store));
	if(!temp) return MOSQ_ERR_NOMEM;

	temp->next = db->msg_store;
	temp->ref_count = 0;
	if(source){
		temp->source_id = _mosquitto_strdup(source);
	}else{
		temp->source_id = _mosquitto_strdup("");
	}
	if(!temp->source_id){
		_mosquitto_free(temp);
		_mosquitto_log_printf(NULL, MOSQ_LOG_ERR, "Error: Out of memory.");
		return MOSQ_ERR_NOMEM;
	}
	temp->source_mid = source_mid;
	temp->msg.mid = 0;
	temp->msg.qos = qos;
	temp->msg.retain = retain;
	if(topic){
		temp->msg.topic = _mosquitto_strdup(topic);
		if(!temp->msg.topic){
			_mosquitto_free(temp->source_id);
			_mosquitto_free(temp);
			_mosquitto_log_printf(NULL, MOSQ_LOG_ERR, "Error: Out of memory.");
			return MOSQ_ERR_NOMEM;
		}
	}else{
		temp->msg.topic = NULL;
	}
	temp->msg.payloadlen = payloadlen;
	if(payloadlen){
		temp->msg.payload = _mosquitto_malloc(sizeof(char)*payloadlen);
		if(!temp->msg.payload){
			if(temp->source_id) _mosquitto_free(temp->source_id);
			if(temp->msg.topic) _mosquitto_free(temp->msg.topic);
			if(temp->msg.payload) _mosquitto_free(temp->msg.payload);
			_mosquitto_free(temp);
			return MOSQ_ERR_NOMEM;
		}
		memcpy(temp->msg.payload, payload, sizeof(char)*payloadlen);
	}else{
		temp->msg.payload = NULL;
	}

	if(!temp->source_id || (payloadlen && !temp->msg.payload)){
		if(temp->source_id) _mosquitto_free(temp->source_id);
		if(temp->msg.topic) _mosquitto_free(temp->msg.topic);
		if(temp->msg.payload) _mosquitto_free(temp->msg.payload);
		_mosquitto_free(temp);
		return 1;
	}
	temp->dest_ids = NULL;
	temp->dest_id_count = 0;
	db->msg_store_count++;
	db->msg_store = temp;
	(*stored) = temp;

	if(!store_id){
		temp->db_id = ++db->last_db_id;
	}else{
		temp->db_id = store_id;
	}

	return MOSQ_ERR_SUCCESS;
}

int mqtt3_db_message_store_find(struct mosquitto *context, uint16_t mid, struct mosquitto_msg_store **stored)
{
	struct mosquitto_client_msg *tail;

	if(!context) return MOSQ_ERR_INVAL;

	*stored = NULL;
	tail = context->msgs;
	while(tail){
		if(tail->store->source_mid == mid && tail->direction == mosq_md_in){
			*stored = tail->store;
			return MOSQ_ERR_SUCCESS;
		}
		tail = tail->next;
	}

	return 1;
}

/* Called on reconnect to set outgoing messages to a sensible state and force a
 * retry, and to set incoming messages to expect an appropriate retry. */
int mqtt3_db_message_reconnect_reset(struct mosquitto *context)
{
	struct mosquitto_client_msg *msg;
	struct mosquitto_client_msg *prev = NULL;
	int count;

	msg = context->msgs;
	context->msg_count = 0;
	context->msg_count12 = 0;
	while(msg){
		context->last_msg = msg;

		context->msg_count++;
		if(msg->qos > 0){
			context->msg_count12++;
		}

		if(msg->direction == mosq_md_out){
			if(msg->state != mosq_ms_queued){
				switch(msg->qos){
					case 0:
						msg->state = mosq_ms_publish_qos0;
						break;
					case 1:
						msg->state = mosq_ms_publish_qos1;
						break;
					case 2:
						if(msg->state == mosq_ms_wait_for_pubcomp){
							msg->state = mosq_ms_resend_pubrel;
						}else{
							msg->state = mosq_ms_publish_qos2;
						}
						break;
				}
			}
		}else{
			if(msg->qos != 2){
				/* Anything <QoS 2 can be completely retried by the client at
				 * no harm. */
				_message_remove(context, &msg, prev);
			}else{
				/* Message state can be preserved here because it should match
				 * whatever the client has got. */
			}
		}
		prev = msg;
		if(msg) msg = msg->next;
	}
	/* Messages received when the client was disconnected are put
	 * in the mosq_ms_queued state. If we don't change them to the
	 * appropriate "publish" state, then the queued messages won't
	 * get sent until the client next receives a message - and they
	 * will be sent out of order.
	 */
	if(context->msgs){
		count = 0;
		msg = context->msgs;
		while(msg && (max_inflight == 0 || count < max_inflight)){
			if(msg->state == mosq_ms_queued){
				switch(msg->qos){
					case 0:
						msg->state = mosq_ms_publish_qos0;
						break;
					case 1:
						msg->state = mosq_ms_publish_qos1;
						break;
					case 2:
						msg->state = mosq_ms_publish_qos2;
						break;
				}
			}
			msg = msg->next;
			count++;
		}
	}

	return MOSQ_ERR_SUCCESS;
}

int mqtt3_db_message_timeout_check(struct mosquitto_db *db, unsigned int timeout)
{
	int i;
	time_t threshold;
	enum mosquitto_msg_state new_state;
	struct mosquitto *context;
	struct mosquitto_client_msg *msg;

	threshold = mosquitto_time() - timeout;
	
	for(i=0; i<db->context_count; i++){
		context = db->contexts[i];
		if(!context) continue;

		msg = context->msgs;
		while(msg){
			new_state = mosq_ms_invalid;
			if(msg->timestamp < threshold && msg->state != mosq_ms_queued){
				switch(msg->state){
					case mosq_ms_wait_for_puback:
						new_state = mosq_ms_publish_qos1;
						break;
					case mosq_ms_wait_for_pubrec:
						new_state = mosq_ms_publish_qos2;
						break;
					case mosq_ms_wait_for_pubrel:
						new_state = mosq_ms_send_pubrec;
						break;
					case mosq_ms_wait_for_pubcomp:
						new_state = mosq_ms_resend_pubrel;
						break;
					default:
						break;
				}
				if(new_state != mosq_ms_invalid){
					msg->timestamp = mosquitto_time();
					msg->state = new_state;
					msg->dup = true;
				}
			}
			msg = msg->next;
		}
	}

	return MOSQ_ERR_SUCCESS;
}

int mqtt3_db_message_release(struct mosquitto_db *db, struct mosquitto *context, uint16_t mid, enum mosquitto_msg_direction dir)
{
	struct mosquitto_client_msg *tail, *last = NULL;
	int qos;
	int retain;
	char *topic;
	char *source_id;
	int msg_index = 0;
	bool deleted = false;

	if(!context) return MOSQ_ERR_INVAL;

	tail = context->msgs;
	while(tail){
		msg_index++;
		if(tail->state == mosq_ms_queued && msg_index <= max_inflight){
			tail->timestamp = mosquitto_time();
			if(tail->direction == mosq_md_out){
				switch(tail->qos){
					case 0:
						tail->state = mosq_ms_publish_qos0;
						break;
					case 1:
						tail->state = mosq_ms_publish_qos1;
						break;
					case 2:
						tail->state = mosq_ms_publish_qos2;
						break;
				}
			}else{
				if(tail->qos == 2){
					_mosquitto_send_pubrec(context, tail->mid);
					tail->state = mosq_ms_wait_for_pubrel;
				}
			}
		}
		if(tail->mid == mid && tail->direction == dir){
			qos = tail->store->msg.qos;
			topic = tail->store->msg.topic;
			retain = tail->retain;
			source_id = tail->store->source_id;

			/* topic==NULL should be a QoS 2 message that was
			 * denied/dropped and is being processed so the client doesn't
			 * keep resending it. That means we don't send it to other
			 * clients. */
			if(!topic || !mqtt3_db_messages_queue(db, source_id, topic, qos, retain, tail->store)){
				_message_remove(context, &tail, last);
				deleted = true;
			}else{
				return 1;
			}
		}else{
			last = tail;
			tail = tail->next;
		}
		if(msg_index > max_inflight && deleted){
			return MOSQ_ERR_SUCCESS;
		}
	}
	if(deleted){
		return MOSQ_ERR_SUCCESS;
	}else{
		return 1;
	}
}

int mqtt3_db_message_write(struct mosquitto *context)
{
	int rc;
	struct mosquitto_client_msg *tail, *last = NULL;
	uint16_t mid;
	int retries;
	int retain;
	const char *topic;
	int qos;
	uint32_t payloadlen;
	const void *payload;
	int msg_count = 0;

	if(!context || context->sock == -1
			|| (context->state == mosq_cs_connected && !context->id)){
		return MOSQ_ERR_INVAL;
	}

	tail = context->msgs;
	while(tail){
		if(tail->direction == mosq_md_in){
			msg_count++;
		}
		if(tail->state != mosq_ms_queued){
			mid = tail->mid;
			retries = tail->dup;
			retain = tail->retain;
			topic = tail->store->msg.topic;
			qos = tail->qos;
			payloadlen = tail->store->msg.payloadlen;
			payload = tail->store->msg.payload;

			switch(tail->state){
				case mosq_ms_publish_qos0:
					rc = _mosquitto_send_publish(context, mid, topic, payloadlen, payload, qos, retain, retries);
					if(!rc){
						_message_remove(context, &tail, last);
					}else{
						return rc;
					}
					break;

				case mosq_ms_publish_qos1:
					rc = _mosquitto_send_publish(context, mid, topic, payloadlen, payload, qos, retain, retries);
					if(!rc){
						tail->timestamp = mosquitto_time();
						tail->dup = 1; /* Any retry attempts are a duplicate. */
						tail->state = mosq_ms_wait_for_puback;
					}else{
						return rc;
					}
					last = tail;
					tail = tail->next;
					break;

				case mosq_ms_publish_qos2:
					rc = _mosquitto_send_publish(context, mid, topic, payloadlen, payload, qos, retain, retries);
					if(!rc){
						tail->timestamp = mosquitto_time();
						tail->dup = 1; /* Any retry attempts are a duplicate. */
						tail->state = mosq_ms_wait_for_pubrec;
					}else{
						return rc;
					}
					last = tail;
					tail = tail->next;
					break;
				
				case mosq_ms_send_pubrec:
					rc = _mosquitto_send_pubrec(context, mid);
					if(!rc){
						tail->state = mosq_ms_wait_for_pubrel;
					}else{
						return rc;
					}
					last = tail;
					tail = tail->next;
					break;

				case mosq_ms_resend_pubrel:
					rc = _mosquitto_send_pubrel(context, mid, true);
					if(!rc){
						tail->state = mosq_ms_wait_for_pubcomp;
					}else{
						return rc;
					}
					last = tail;
					tail = tail->next;
					break;

				case mosq_ms_resend_pubcomp:
					rc = _mosquitto_send_pubcomp(context, mid);
					if(!rc){
						tail->state = mosq_ms_wait_for_pubrel;
					}else{
						return rc;
					}
					last = tail;
					tail = tail->next;
					break;

				default:
					last = tail;
					tail = tail->next;
					break;
			}
		}else{
			/* state == mosq_ms_queued */
			if(tail->direction == mosq_md_in && (max_inflight == 0 || msg_count < max_inflight)){
				if(tail->qos == 2){
					tail->state = mosq_ms_send_pubrec;
				}
			}else{
				last = tail;
				tail = tail->next;
			}
		}
	}

	return MOSQ_ERR_SUCCESS;
}

void mqtt3_db_store_clean(struct mosquitto_db *db)
{
	/* FIXME - this may not be necessary if checks are made when messages are removed. */
	struct mosquitto_msg_store *tail, *last = NULL;
	int i;
	assert(db);

	tail = db->msg_store;
	while(tail){
		if(tail->ref_count == 0){
			if(tail->source_id) _mosquitto_free(tail->source_id);
			if(tail->dest_ids){
				for(i=0; i<tail->dest_id_count; i++){
					if(tail->dest_ids[i]) _mosquitto_free(tail->dest_ids[i]);
				}
				_mosquitto_free(tail->dest_ids);
			}
			if(tail->msg.topic) _mosquitto_free(tail->msg.topic);
			if(tail->msg.payload) _mosquitto_free(tail->msg.payload);
			if(last){
				last->next = tail->next;
				_mosquitto_free(tail);
				tail = last->next;
			}else{
				db->msg_store = tail->next;
				_mosquitto_free(tail);
				tail = db->msg_store;
			}
			db->msg_store_count--;
		}else{
			last = tail;
			tail = tail->next;
		}
	}
}

void mqtt3_db_limits_set(int inflight, int queued)
{
	max_inflight = inflight;
	max_queued = queued;
}

void mqtt3_db_vacuum(void)
{
	/* FIXME - reimplement? */
}

