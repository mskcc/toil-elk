SHELL:=/bin/bash
UNAME:=$(shell uname)
USERNAME:=$(shell whoami)
IP:=127.0.0.1
HOST:=localhost
.ONESHELL:

export PATH:=$(CURDIR):$(CURDIR)/conda/bin:$(PATH)
unexport PYTHONPATH
unexport PYTHONHOME

define help
...
endef
export help
help:
	@printf "$$help"
.PHONY: help


# ~~~~~ SOFTWARE INSTALLATION ~~~~~ #
# versions for Mac or Linux
ifeq ($(UNAME), Darwin)
CONDASH:=Miniconda3-4.7.12.1-MacOSX-x86_64.sh
ES_GZ:=elasticsearch-7.10.1-darwin-x86_64.tar.gz
LS_GZ:=logstash-7.10.1-darwin-x86_64.tar.gz
KIBANA_GZ:=kibana-7.10.1-darwin-x86_64.tar.gz
FB_GZ:=filebeat-7.10.1-darwin-x86_64.tar.gz
YQ_BIN:=yq_darwin_amd64
export KIBANA_HOME:=$(CURDIR)/kibana-7.10.1-darwin-x86_64
export FB_HOME:=$(CURDIR)/filebeat-7.10.1-darwin-x86_64
endif

ifeq ($(UNAME), Linux)
CONDASH:=Miniconda3-4.7.12.1-Linux-x86_64.sh
ES_GZ:=elasticsearch-7.10.1-linux-x86_64.tar.gz
LS_GZ:=logstash-7.10.1-linux-x86_64.tar.gz
KIBANA_GZ:=kibana-7.10.1-linux-x86_64.tar.gz
FB_GZ:=filebeat-7.10.1-linux-x86_64.tar.gz
YQ_BIN:=yq_linux_amd64
export KIBANA_HOME:=$(CURDIR)/kibana-7.10.1-linux-x86_64
export FB_HOME:=$(CURDIR)/filebeat-7.10.1-linux-x86_64
endif

YQ_URL:=https://github.com/mikefarah/yq/releases/download/4.0.0/$(YQ_BIN)
FB_URL:=https://artifacts.elastic.co/downloads/beats/filebeat/$(FB_GZ)
ES_BIN_URL:=https://artifacts.elastic.co/downloads/elasticsearch/$(ES_GZ)
KIBANA_URL:=https://artifacts.elastic.co/downloads/kibana/$(KIBANA_GZ)
LS_URL:=https://artifacts.elastic.co/downloads/logstash/$(LS_GZ)

export ES_HOME:=$(CURDIR)/elasticsearch-7.10.1
export LS_HOME:=$(CURDIR)/logstash-7.10.1

export PATH:=$(FB_HOME):$(LS_HOME)/bin:$(ES_HOME)/bin:$(PATH)


# not used in this demo but useful;
$(YQ_BIN):
	wget "$(YQ_URL)" && chmod +x $(YQ_BIN)

yq: $(YQ_BIN)
	ln -s $(YQ_BIN) yq

CONDAURL:=https://repo.continuum.io/miniconda/$(CONDASH)
conda:
	@echo ">>> Setting up conda..."
	@wget "$(CONDAURL)" && \
	bash "$(CONDASH)" -b -p conda && \
	rm -f "$(CONDASH)"

$(ES_GZ):
	wget "$(ES_BIN_URL)"

$(ES_HOME): $(ES_GZ)
	tar -xzf $(ES_GZ)

$(KIBANA_HOME):
	wget "$(KIBANA_URL)" && \
	tar -xzf $(KIBANA_GZ)

$(LS_HOME):
	wget "$(LS_URL)" && \
	tar -xzf $(LS_GZ)

$(LOGDIR):
	mkdir -p "$(LOGDIR)"

install: conda $(ES_HOME) $(KIBANA_HOME) $(LS_HOME) $(LS_PS_JDBC) $(LOGDIR)
	pip install \
	cwltool==3.0.20201203173111 \
	cwlref-runner==1.0 \
	toil[all]==5.0.0

# interactive shell with environment populated
bash:
	bash
