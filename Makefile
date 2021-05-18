SHELL:=/bin/bash
UNAME:=$(shell uname)
USERNAME:=$(shell whoami)
IP:=127.0.0.1
HOST:=localhost
.ONESHELL:

define help
...
endef
export help
help:
	@printf "$$help"
.PHONY: help


# ~~~~~ SOFTWARE INSTALLATION ~~~~~ #
# versions for Mac or Linux
ifeq ($(UNAME), Linux)
CONDASH:=Miniconda3-4.7.12.1-Linux-x86_64.sh
ES_GZ:=elasticsearch-7.10.1-linux-x86_64.tar.gz
LS_GZ:=logstash-7.10.1-linux-x86_64.tar.gz
KIBANA_GZ:=kibana-7.10.1-linux-x86_64.tar.gz
# https://www.elastic.co/guide/en/beats/filebeat/7.10/filebeat-installation-configuration.html
FB_GZ:=filebeat-7.10.1-linux-x86_64.tar.gz
export KIBANA_HOME:=$(CURDIR)/kibana-7.10.1-linux-x86_64
export FB_HOME:=$(CURDIR)/filebeat-7.10.1-linux-x86_64
endif

ifeq ($(UNAME), Darwin)
CONDASH:=Miniconda3-4.7.12.1-MacOSX-x86_64.sh
ES_GZ:=elasticsearch-7.10.1-darwin-x86_64.tar.gz
LS_GZ:=logstash-7.10.1-darwin-x86_64.tar.gz
KIBANA_GZ:=kibana-7.10.1-darwin-x86_64.tar.gz
FB_GZ:=filebeat-7.10.1-darwin-x86_64.tar.gz
export KIBANA_HOME:=$(CURDIR)/kibana-7.10.1-darwin-x86_64
export FB_HOME:=$(CURDIR)/filebeat-7.10.1-darwin-x86_64
endif

# not tied to system version
export ES_HOME:=$(CURDIR)/elasticsearch-7.10.1
export LS_HOME:=$(CURDIR)/logstash-7.10.1

# URLs to download the binaries
FB_URL:=https://artifacts.elastic.co/downloads/beats/filebeat/$(FB_GZ)
ES_BIN_URL:=https://artifacts.elastic.co/downloads/elasticsearch/$(ES_GZ)
KIBANA_URL:=https://artifacts.elastic.co/downloads/kibana/$(KIBANA_GZ)
LS_URL:=https://artifacts.elastic.co/downloads/logstash/$(LS_GZ)


# update environment for the software
export PATH:=$(FB_HOME):$(LS_HOME)/bin:$(ES_HOME)/bin:$(CURDIR):$(CURDIR)/conda/bin:$(PATH)
unexport PYTHONPATH
unexport PYTHONHOME

# download and install for conda
CONDAURL:=https://repo.continuum.io/miniconda/$(CONDASH)
conda:
	@echo ">>> Setting up conda..."
	@wget "$(CONDAURL)" && \
	bash "$(CONDASH)" -b -p conda && \
	rm -f "$(CONDASH)"

# download and installs for Logstash, Filebeat, ElasticSearch, Kibana
$(FB_GZ):
	wget "$(FB_URL)"

$(FB_HOME): $(FB_GZ)
	tar -xzf $(FB_GZ)

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

# put system logs for software here
LOG_DIR:=$(CURDIR)/logs
$(LOG_DIR):
	mkdir -p "$(LOG_DIR)"

# config files for software go here
CONFIG_DIR:=$(CURDIR)/config
$(CONFIG_DIR):
	mkdir -p "$(CONFIG_DIR)"

# install for CWLTool, Toil
install: conda $(ES_HOME) $(KIBANA_HOME) $(LS_HOME) $(LOG_DIR) $(FB_HOME)
	conda install conda-forge::jq # conda-forge::yq <- this one has issues installing...
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


# local dirs to store data for the software
FB_DATA:=$(CURDIR)/filebeat-data
$(FB_DATA):
	mkdir -p "$(FB_DATA)"

# ~~~~~ Filebeat ~~~~~ #
# https://www.elastic.co/guide/en/beats/filebeat/7.10/filebeat-installation-configuration.html
# demo log file input for filebeat;
# wget https://download.elastic.co/demos/logstash/gettingstarted/logstash-tutorial.log.gz

# this is the file that we want Filebeat to ingest
FB_INPUT_LOGFILE:=$(CURDIR)/logstash-tutorial.log
# example template config file; set IP address, ports, here, the input log path will get overwritten
FB_CONFIG_EXAMPLE:=$(CONFIG_DIR)/filebeat-example.yml

# this will be the log file that we use when we run Filebeat;
# need to hard-code in the absolute path to the input log file we want to read in, this will be set dynamically at run time
# $ make filebeat-run FB_CONFIG=/path/to/new/filebeat-config.yml FB_INPUT_LOGFILE=/path/to/toil/run.log
FB_CONFIG:=$(CONFIG_DIR)/filebeat.yml
$(FB_CONFIG):$(FB_CONFIG_EXAMPLE)
	sed -e 's|/path/to/logs/logstash-tutorial.log|$(FB_INPUT_LOGFILE)|g' "$(FB_CONFIG_EXAMPLE)" > $(FB_CONFIG)
.PHONY:$(FB_CONFIG)

filebeat-run: $(FB_CONFIG) $(FB_DATA) $(LOG_DIR)
	filebeat -e -c "$(FB_CONFIG)" -d "publish" \
	--path.data "$(FB_DATA)" \
	--path.logs "$(LOG_DIR)"
