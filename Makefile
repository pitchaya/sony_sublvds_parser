

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(shell pwd)/sublvds_word_aligner.v # $(shell pwd)/async.v 
TOPLEVEL = word_aligner
MODULE = test_word_aligner

include $(shell cocotb-config --makefiles)/Makefile.sim