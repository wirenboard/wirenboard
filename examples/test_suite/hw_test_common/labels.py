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


font_path = os.path.join(os.path.dirname(__file__), "LiberationMono-Bold.ttf")

def make_font(path, size):
    return ImageFont.truetype(path, size)



def _font_get_text_size(font, text):
    img = Image.new('LA',(1200,500))
    draw = ImageDraw.Draw(img)
    draw.text((0, 0),text,1,font=font)
    bbox = img.getbbox()
    if bbox:
        return img.getbbox()[2:4]
    else:
        return (0,0)



def make_fiting_font(text, font_path, height):
    
    size = 100 # best guess
    step = 30
    going_up = True

    max_undershot_ratio = 0.04 

    while size >= 0:
        font =  make_font(font_path, size)
        cur_height = _font_get_text_size(font, text)[1]
        if  max_undershot_ratio * height > height - cur_height >=  0:
            break

        if ((cur_height < height) ^ going_up):
            # miss!
            going_up = not going_up
            if step == 1:
                break
            else:
                step = step / 2

        if going_up:
            size += step
        else:
            size -= step

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

def make_barcode(contents, out_fname, code_type=20, height=35, scale=5):
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
                           barcode_height=35,
                           barcode_scale=5,
                           caption_contents = None,
                           caption_ratio = 0.2
                           ):

    barcode_tmpfile = tempfile.NamedTemporaryFile(delete = False, suffix='.png')
    try:
        make_barcode(barcode_contents, barcode_tmpfile.name,
            code_type=barcode_type, height=barcode_height,
            scale=barcode_scale)

        barcode = Image.open(barcode_tmpfile.name)
        print barcode.size

        # text heigh ratio of the total picture height
        text_height = int(barcode.size[1] * 1.0 / (1.0 / caption_ratio - 1))

        font = make_fiting_font(caption_contents, font_path, text_height)
        text_size = _font_get_text_size(font, caption_contents)
        print text_size

        caption_img = Image.new(barcode.mode,
            text_size,
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


def print_label(fname, copies=1, space_pt=10):
    printer_name = 'DYMO-LabelManager-PnP'
    conn = cups.Connection()
    conn.cancelAllJobs(printer_name)
    conn.enablePrinter(printer_name)

    resolution = get_printer_resolution(printer_name)

    # for tape, width is fixed and while the height vary
    # i.e. printing is done in landscape mode
    printable_width_pt = 25

    
    orig_img = Image.open(fname)

    img_height = orig_img.size[1]

    if copies > 1:
        space_px = space_pt * img_height / printable_width_pt

        img = Image.new(orig_img.mode, 
            (orig_img.size[0] * copies + space_px * (copies - 1), orig_img.size[1]), 'White')
        for i in xrange(copies):
            img.paste(orig_img, (i * (orig_img.size[0] + space_px), 0))
    else:
        img = orig_img

    img_width = img.size[0]

    printable_height_pt = printable_width_pt * 1.0 / img_height * img_width

    page_size = "Custom.%fx%f" % (printable_width_pt, printable_height_pt)
    # page_size = 'w35h144'

    options = { 'PageSize' : page_size,
                'scaling'  : '100',
                'DymoHalftoning' : 'Default'
              }

    tmpfile = tempfile.NamedTemporaryFile(delete = False, suffix='.png')
    try:
        img.save(tmpfile.name)
        conn.printFile(printer_name, tmpfile.name, "Label", options)
    finally:
        tmpfile.close()

