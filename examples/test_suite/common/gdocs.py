import json
import gspread
from oauth2client.client import SignedJwtAssertionCredentials




class GSheetsLog(object):
    IMEI_COL = 3
    def __init__(self, url, key_fname):
		json_key = json.load(open(key_fname))
		scope = ['https://spreadsheets.google.com/feeds']

		credentials = SignedJwtAssertionCredentials(json_key['client_email'], json_key['private_key'], scope)
		self.gc = gspread.authorize(credentials)

		self.wks = self.gc.open_by_url(url)
		self.worksheet = self.wks.get_worksheet(0)

    def find_row(self, imei):
        imei_sn = str(imei)
        sn_list = self.worksheet.col_values(self.IMEI_COL)[1:]
        if imei_sn not in sn_list:
            return

        return sn_list.index(imei) + 2

    def insert_row(self, row_number, row, position = 1):
        if len(row) == 0:
            return

        name_begin = self.worksheet.get_addr_int(row_number, position)
        name_end = self.worksheet.get_addr_int(row_number, position + len(row) - 1)

        cell_range = self.worksheet.range("%s:%s" % (name_begin, name_end))
        for i, cell in enumerate(cell_range):
            cell.value = row[i]
        self.worksheet.update_cells(cell_range)

    @staticmethod
    def split_imei(imei):
        imei = str(imei)
        if not imei.isdigit():
            raise RuntimeError("imei is not a numberical")

        if len(imei) !=  15:
            raise RuntimeError("wrong imei len")

        prefix = imei[:8]
        sn = imei[8:14]
        crc = imei[14]

        return int(prefix), int(sn), int(crc)


    def update_row_by_imei(self, imei, row):
        row_number = self.find_row(imei)
        if row_number is None:
            self.worksheet.append_row(row)
        else:
            self.insert_row(row_number, row)

    def update_data(self, imei, qc, data_row):
        imei_prefix, imei_sn, imei_crc = self.split_imei(imei)
        row = [qc, imei_sn, imei, imei_prefix, imei_crc] + data_row
        self.update_row_by_imei(imei, row)




if __name__ == '__main__':
    log = GSheetsLog('https://docs.google.com/a/contactless.ru/spreadsheets/d/1g6hC75iE88_vwFXX7P2semwyADEWB13KMc0nDmB62LI/edit#gid=0')
    print log.find_row('342')
    #~ log.insert_row(5, ['1','OK','3','4','5'])
    log.update_data('868204001111112', 'OK', ['test1', 'test2'])
