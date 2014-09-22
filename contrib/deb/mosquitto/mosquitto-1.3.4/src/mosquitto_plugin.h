/*
Copyright (c) 2012,2013 Roger Light <roger@atchoo.org>
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

#ifndef MOSQUITTO_PLUGIN_H
#define MOSQUITTO_PLUGIN_H

#define MOSQ_AUTH_PLUGIN_VERSION 2

#define MOSQ_ACL_NONE 0x00
#define MOSQ_ACL_READ 0x01
#define MOSQ_ACL_WRITE 0x02

struct mosquitto_auth_opt {
	char *key;
	char *value;
};

/*
 * To create an authentication plugin you must include this file then implement
 * the functions listed below. The resulting code should then be compiled as a
 * shared library. Using gcc this can be achieved as follows:
 *
 * gcc -I<path to mosquitto_plugin.h> -fPIC -shared plugin.c -o plugin.so
 */

/*
 * Function: mosquitto_auth_plugin_version
 *
 * The broker will call this function immediately after loading the plugin to
 * check it is a supported plugin version. Your code must simply return
 * MOSQ_AUTH_PLUGIN_VERSION.
 */
int mosquitto_auth_plugin_version(void);

/*
 * Function: mosquitto_auth_plugin_init
 *
 * Called after the plugin has been loaded and <mosquitto_auth_plugin_version>
 * has been called. This will only ever be called once and can be used to
 * initialise the plugin.
 *
 * Parameters:
 *
 *	user_data :      The pointer set here will be passed to the other plugin
 *	                 functions. Use to hold connection information for example.
 *	auth_opts :      Pointer to an array of struct mosquitto_auth_opt, which
 *	                 provides the plugin options defined in the configuration file.
 *	auth_opt_count : The number of elements in the auth_opts array.
 *
 * Return value:
 *	Return 0 on success
 *	Return >0 on failure.
 */
int mosquitto_auth_plugin_init(void **user_data, struct mosquitto_auth_opt *auth_opts, int auth_opt_count);

/*
 * Function: mosquitto_auth_plugin_cleanup
 *
 * Called when the broker is shutting down. This will only ever be called once.
 * Note that <mosquitto_auth_security_cleanup> will be called directly before
 * this function.
 *
 * Parameters:
 *
 *	user_data :      The pointer provided in <mosquitto_auth_plugin_init>.
 *	auth_opts :      Pointer to an array of struct mosquitto_auth_opt, which
 *	                 provides the plugin options defined in the configuration file.
 *	auth_opt_count : The number of elements in the auth_opts array.
 *
 * Return value:
 *	Return 0 on success
 *	Return >0 on failure.
 */
int mosquitto_auth_plugin_cleanup(void *user_data, struct mosquitto_auth_opt *auth_opts, int auth_opt_count);

/*
 * Function: mosquitto_auth_security_init
 *
 * Called when the broker initialises the security functions when it starts up.
 * If the broker is requested to reload its configuration whilst running,
 * <mosquitto_auth_security_cleanup> will be called, followed by this function.
 * In this situation, the reload parameter will be true.
 *
 * Parameters:
 *
 *	user_data :      The pointer provided in <mosquitto_auth_plugin_init>.
 *	auth_opts :      Pointer to an array of struct mosquitto_auth_opt, which
 *	                 provides the plugin options defined in the configuration file.
 *	auth_opt_count : The number of elements in the auth_opts array.
 *	reload :         If set to false, this is the first time the function has
 *	                 been called. If true, the broker has received a signal
 *	                 asking to reload its configuration.
 *
 * Return value:
 *	Return 0 on success
 *	Return >0 on failure.
 */
int mosquitto_auth_security_init(void *user_data, struct mosquitto_auth_opt *auth_opts, int auth_opt_count, bool reload);

/* 
 * Function: mosquitto_auth_security_cleanup
 *
 * Called when the broker cleans up the security functions when it shuts down.
 * If the broker is requested to reload its configuration whilst running,
 * this function will be called, followed by <mosquitto_auth_security_init>.
 * In this situation, the reload parameter will be true.
 *
 * Parameters:
 *
 *	user_data :      The pointer provided in <mosquitto_auth_plugin_init>.
 *	auth_opts :      Pointer to an array of struct mosquitto_auth_opt, which
 *	                 provides the plugin options defined in the configuration file.
 *	auth_opt_count : The number of elements in the auth_opts array.
 *	reload :         If set to false, this is the first time the function has
 *	                 been called. If true, the broker has received a signal
 *	                 asking to reload its configuration.
 *
 * Return value:
 *	Return 0 on success
 *	Return >0 on failure.
 */
int mosquitto_auth_security_cleanup(void *user_data, struct mosquitto_auth_opt *auth_opts, int auth_opt_count, bool reload);

/*
 * Function: mosquitto_auth_acl_check
 *
 * Called by the broker when topic access must be checked. access will be one
 * of MOSQ_ACL_READ (for subscriptions) or MOSQ_ACL_WRITE (for publish). Return
 * MOSQ_ERR_SUCCESS if access was granted, MOSQ_ERR_ACL_DENIED if access was
 * not granted, or MOSQ_ERR_UNKNOWN for an application specific error.
 */
int mosquitto_auth_acl_check(void *user_data, const char *clientid, const char *username, const char *topic, int access);

/*
 * Function: mosquitto_auth_unpwd_check
 *
 * Called by the broker when a username/password must be checked. Return
 * MOSQ_ERR_SUCCESS if the user is authenticated, MOSQ_ERR_AUTH if
 * authentication failed, or MOSQ_ERR_UNKNOWN for an application specific
 * error.
 */
int mosquitto_auth_unpwd_check(void *user_data, const char *username, const char *password);

/*
 * Function: mosquitto_psk_key_get
 *
 * Called by the broker when a client connects to a listener using TLS/PSK.
 * This is used to retrieve the pre-shared-key associated with a client
 * identity.
 *
 * Examine hint and identity to determine the required PSK (which must be a
 * hexadecimal string with no leading "0x") and copy this string into key.
 *
 * Parameters:
 *	user_data :   the pointer provided in <mosquitto_auth_plugin_init>.
 *	hint :        the psk_hint for the listener the client is connecting to.
 *	identity :    the identity string provided by the client
 *	key :         a string where the hex PSK should be copied
 *	max_key_len : the size of key
 *
 * Return value:
 *	Return 0 on success.
 *	Return >0 on failure.
 *	Return >0 if this function is not required.
 */
int mosquitto_auth_psk_key_get(void *user_data, const char *hint, const char *identity, char *key, int max_key_len);

#endif
