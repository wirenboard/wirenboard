#coding: utf-8

import httplib2
import os
import oauth2client
import oauth2client.file


from oauth2client.service_account import ServiceAccountCredentials

# import httplib
# httplib2.debuglevel = 1
# import logging ; logging.basicConfig(level=0)

SCOPES = 'https://www.googleapis.com/auth/spreadsheets'
APPLICATION_NAME = 'Google Sheets API Python Quickstart'
# import requests
import urllib
import json

print "import done"
class GSheetsLog(object):
    BOARD_ID_COL = 3
    _MAGIC_NUMBER = 64

    def get_addr_int(self, row, col):
        """Translates cell's tuple of integers to a cell label.

        The result is a string containing the cell's coordinates in label form.

        :param row: The row of the cell to be converted.
                    Rows start at index 1.

        :param col: The column of the cell to be converted.
                    Columns start at index 1.

        Example:

        >>> wks.get_addr_int(1, 1)
        A1

        """
        row = int(row)
        col = int(col)

        if row < 1 or col < 1:
            raise ValueError('(%s, %s)' % (row, col))

        div = col
        column_label = ''

        while div:
            (div, mod) = divmod(div, 26)
            if mod == 0:
                mod = 26
                div -= 1
            column_label = chr(mod + self._MAGIC_NUMBER) + column_label

        label = '%s%s' % (column_label, row)
        return label


    def _get_credentials(self, key_file):
        """Gets valid user credentials from storage.

        Returns:
            Credentials, the obtained credential.
        """
        home_dir = os.path.expanduser('~')
        credential_dir = os.path.join(home_dir, '.credentials')
        if not os.path.exists(credential_dir):
            os.makedirs(credential_dir)
        credential_path = os.path.join(credential_dir,
                                       'sheets.googleapis.com-python-quickstart.json')

        store = oauth2client.file.Storage(credential_path)
        credentials = store.get()
        if not credentials or credentials.invalid:
            credentials = ServiceAccountCredentials.from_json_keyfile_name(key_file, SCOPES)
            print('Storing credentials to ' + credential_path)
            store.put(credentials)
        return credentials

    def __init__(self, spreadsheet_id, key_fname):
        credentials = self._get_credentials(key_fname)

        self.http = credentials.authorize(httplib2.Http())

        self.spreadsheet_id = spreadsheet_id


    def get_range_contents(self, range_spec):
        range_spec = urllib.quote(range_spec)
        url = 'https://sheets.googleapis.com/v4/spreadsheets/%s/values/%s?alt=json' % (self.spreadsheet_id, range_spec)

        response, content = self.http.request(url)
        return json.loads(content).get('values')

    def get_cell_content(self, row_number, column_number):
        range_spec = self.get_addr_int(row_number, column_number)

        return self.get_range_contents(range_spec)

    def find_row(self, column_number, cell_content):
        cell_content = str(cell_content)
        range_spec = "%s:%s" % (self.get_addr_int(1, column_number),
                                self.get_addr_int(10000, column_number))

        for i, row in enumerate(self.get_range_contents(range_spec)):
            if row:
                if row[0] == cell_content:
                    return i + 1
        else:
            return None


    def append_row(self, row, position=1):
        url = 'https://sheets.googleapis.com/v4/spreadsheets/%s/values/A%%3AF:append?alt=json&insertDataOption=INSERT_ROWS&valueInputOption=USER_ENTERED' % (self.spreadsheet_id,)

        req_obj = {'values' : [row,] }

        response, content = self.http.request(url, method='POST', body=json.dumps(req_obj))
        # print response, content

    def update_row_by_primary_key(self, column_number, row):
        key = row[column_number - 1]
        row_number = self.find_row(column_number, key)
        if row_number is None:
            self.append_row(row)
        else:
            self.insert_row(row_number, row)


    def insert_row(self, row_number, row, position=1):
        if len(row) == 0:
            return

        name_begin = self.get_addr_int(row_number, position)
        name_end = self.get_addr_int(row_number, position + len(row) - 1)

        range_spec = "%s:%s" % (name_begin, name_end)

        url = 'https://sheets.googleapis.com/v4/spreadsheets/%s/values/%s?alt=json&valueInputOption=RAW' % (self.spreadsheet_id, urllib.quote(range_spec))

        req_obj = { "majorDimension": 'ROWS',
                    'values' : [row,]
                  }

        response, content = self.http.request(url, method='PUT', body=json.dumps(req_obj))

if __name__ == '__main__':
    log = GSheetsLog('1gN56RBi__Y7n44XVklc1vjl_FRCkizIJeHsrXZRItr0', 'Commissioning-30b68b322b7c.json')
    print log.find_row(3, '6020112')
    # log.append_row(['a','b','c','d','e'])
    log.append_row(['=1+2'])
    print log.get_cell_content(708, 1)
    # log.insert_row(710, ['a',None,'c','d','e'])
    log.update_row_by_primary_key(3, ['e', 'e', 'test123', 'g', 'j', '123'])
    #~ log.insert_row(5, ['1','OK','3','4','5'])
    # log.update_data('868204001111112', 'OK', ['test1', 'test2'])
# =MAX(INDIRECT("$C$1:" & ADDRESS(ROW()-1;COLUMN())))+1