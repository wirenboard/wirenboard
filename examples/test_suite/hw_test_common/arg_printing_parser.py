import argparse

class ArgPrintingParser(argparse.ArgumentParser):
    def __init__(self, *args, **kwargs):
        self.__parser_arguments = {}
        super(ArgPrintingParser, self).__init__(*args, **kwargs)

    def add_argument(self, *args, **kwargs):
        dest = kwargs.get('dest')
        self.__parser_arguments[dest] = kwargs.get('help')
        return super(ArgPrintingParser, self).add_argument(*args, **kwargs)

    def print_args(self, args):
        print "======== Command-line parameters: =========="
        for k, v in args._get_kwargs():
            if k in self.__parser_arguments:
                print "%s: %s" % (self.__parser_arguments[k], v)
        print "============================================"

