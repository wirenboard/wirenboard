import os


def get_fw_version():
    try:
        return open("/etc/wb-fw-version").read().strip()
    except:
        return None


def get_wb_version():
    return os.environ['WB_VERSION']
