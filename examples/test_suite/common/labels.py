#!/usr/bin/python
import sys
import subprocess
import tempfile
import os
import re
import cups

from PIL import Image
from PIL import ImageFont
from PIL import ImageDraw

font_path = "LiberationMono-Bold.ttf"
def make_font(path, size):
    return ImageFont.truetype(path, size)

def make_fiting_font(text, font_path, height):
    size = 1
    font =  make_font(font_path, size)

    while font.getsize(text)[1] < height:
        size += 1
        font = make_font(font_path, size)
    # font = make_font(font_path, font.size - 1)

    return font

def combine_images(img1, img2):
    """ Two horizontally centered images on top of each other. """

    # calculate the combined image size

    height = img1.size[1] + img2.size[1]
    width = max(img1.size[0], img2.size[0])

    img = Image.new(img1.mode, (width, height), 'white')

    img1_h_offset = (img.size[0] - img1.size[0]) / 2
    img.paste(img1, (img1_h_offset, 0))

    img2_h_offset = (img.size[0] - img2.size[0]) / 2
    img.paste(img2, (img2_h_offset, img1.size[1]))


    return img

def make_barcode(contents, out_fname, code_type=20, height=15, scale=5):
    proc = subprocess.Popen(['/usr/bin/zint',
                             '-o', out_fname,
                             '--height=%d' % height,
                             '--barcode=%d' % code_type,
                             '--scale=%d' % scale,
                             '--notext', '-d', contents,
                             ])
    proc.communicate()
    ret = proc.wait()
    if ret != 0:
        raise RuntimeError("subprocess returned %d" % ret)



def make_barcode_w_caption(out_fname, barcode_contents, 
                           barcode_type=20,
                           barcode_height=15,
                           barcode_scale=5,
                           caption_contents = None,
                           caption_ratio = 0.35
                           ):

    barcode_tmpfile = tempfile.NamedTemporaryFile(delete = False, suffix='.png')
    try:
        make_barcode(barcode_contents, barcode_tmpfile.name,
            code_type=barcode_type, height=barcode_height,
            scale=barcode_scale)

        barcode = Image.open(barcode_tmpfile.name)
        # print barcode.width, barcode.size[1]

        # text heigh ratio of the total picture height
        text_height = int(barcode.size[1] * 1.0 / (1.0 / caption_ratio - 1))

        font = make_fiting_font(caption_contents, font_path, text_height)

        caption_img = Image.new(barcode.mode,
            font.getsize(caption_contents),
            'white')
        caption_draw = ImageDraw.Draw(caption_img)
        # font = ImageFont.truetype(<font-file>, <font-size>)

        # draw.text((x, y),"Sample Text",(r,g,b))
        caption_draw.text((0, 0),caption_contents,(0,0,0),font=font)


        composite_img = combine_images(barcode, caption_img)
        composite_img.save(out_fname)
    finally:
        os.remove(barcode_tmpfile.name)

    # caption_text = "A:33 SN:1101228"

def get_printer_resolution(printer_name):
    c = cups.Connection()
    ppd = cups.PPD(c.getPPD(printer_name))
    for option_group in ppd.optionGroups:
        for option in option_group.options:
            if option.keyword == 'Resolution':
                return int(re.sub(r'[^\d-]+', '', option.choices[0]['choice']))

    return None


def print_label(fname):
    printer_name = 'DYMO-LabelManager-PnP'
    conn = cups.Connection()
    options = { 'PageSize' : 'w35h144',
                'scaling'  : '100',
                'DymoHalftoning' : 'Default'
              }

    conn.printFile(printer_name, fname, "Label", options)
