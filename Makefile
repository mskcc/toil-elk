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

LOG_DIR:=$(CURDIR)/logs
$(LOG_DIR):
	mkdir -p "$(LOG_DIR)"

install: conda $(ES_HOME) $(KIBANA_HOME) $(LS_HOME) $(LS_PS_JDBC) $(LOG_DIR)
	pip install \
	cwltool==3.0.20201203173111 \
	cwlref-runner==1.0 \
	toil[all]==5.2.0

# interactive shell with environment populated
bash:
	bash

WORK_DIR:=$(CURDIR)/work
TMP_DIR:=$(WORK_DIR)/tmp
$(WORK_DIR):
	mkdir -p "$(WORK_DIR)"
$(TMP_DIR):
	mkdir -p "$(TMP_DIR)"



# ~~~~~ RUN ~~~~~ #
RUN_ID:=$(shell date +%s)
RUN_LOG_DIR:=$(LOG_DIR)/$(RUN_ID)
$(RUN_LOG_DIR):
	mkdir -p "$(RUN_LOG_DIR)"

# run the workflow
run-cwltool:
	cwl-runner workflow.cwl

TOIL_LOG:=$(RUN_LOG_DIR)/toil.log
TOIL_STDOUT_LOG:=$(RUN_LOG_DIR)/toil.stdout.log
TOIL_CLUSTERSTATS:=$(RUN_LOG_DIR)/toil_cluster.json
run-toil: $(RUN_LOG_DIR) $(WORK_DIR) $(TMP_DIR)
	set -eu -o pipefail
	toil-cwl-runner \
	--batchSystem lsf \
	--retryCount 1 \
	--disableCaching True \
	--disable-user-provenance \
	--disable-host-provenance \
	--clean onSuccess \
	--cleanWorkDir onSuccess \
	--writeLogs "$(RUN_LOG_DIR)" \
	--writeLogsFromAllJobs \
	--logFile "$(TOIL_LOG)" \
	--workDir "$(WORK_DIR)" \
	--tmpdir-prefix "$(TMP_DIR)" \
	--clusterStats "$(TOIL_CLUSTERSTATS)" \
	workflow.cwl 2>&1 | tee "$(TOIL_STDOUT_LOG)"
# --defaultMemory 100M \
# --defaultCores 1 \
# --maxMemory 100M \
# --maxCores 1 \
# --maxLocalJobs 10 \

clean:
	rm -rf "$(WORK_DIR)"
