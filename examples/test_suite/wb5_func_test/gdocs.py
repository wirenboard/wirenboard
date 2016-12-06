import json
import gspread
from oauth2client.service_account import ServiceAccountCredentials


class GSheetsLog(object):
    BOARD_ID_COL = 3

    def __init__(self, url, key_fname):
        scope = ['https://spreadsheets.google.com/feeds']
        credentials = ServiceAccountCredentials.from_json_keyfile_name(key_fname, scope)
        self.gc = gspread.authorize(credentials)

        self.wks = self.gc.open_by_url(url)
        self.worksheet = self.wks.get_worksheet(0)

    def find_row(self, board_id):
        board_id = str(board_id)
        sn_list = self.worksheet.col_values(self.BOARD_ID_COL)[1:]
        if board_id not in sn_list:
            return

        return sn_list.index(board_id) + 2

    def insert_row(self, row_number, row, position=1):
        if len(row) == 0:
            return

        name_begin = self.worksheet.get_addr_int(row_number, position)
        name_end = self.worksheet.get_addr_int(row_number, position + len(row) - 1)

        cell_range = self.worksheet.range("%s:%s" % (name_begin, name_end))
        for i, cell in enumerate(cell_range):
            cell.value = row[i]
        self.worksheet.update_cells(cell_range)

    def update_row_by_board_id(self, board_id, row):
        row_number = self.find_row(board_id)
        if row_number is None:
            self.worksheet.append_row(row)
        else:
            self.insert_row(row_number, row)

    def update_data(self, board_id, short_sn, qc, data_row):
        # imei_prefix, imei_sn, imei_crc = self.split_imei(imei)

        row = [qc, short_sn, board_id] + data_row
        self.update_row_by_board_id(board_id, row)


if __name__ == '__main__':
    log = GSheetsLog(
        'https://docs.google.com/a/contactless.ru/spreadsheets/d/1g6hC75iE88_vwFXX7P2semwyADEWB13KMc0nDmB62LI/edit#gid=0')
    print log.find_row('342')
    #~ log.insert_row(5, ['1','OK','3','4','5'])
    log.update_data('868204001111112', 'OK', ['test1', 'test2'])
