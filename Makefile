SHELL:=/bin/bash
UNAME:=$(shell uname)
USERNAME:=$(shell whoami)
IP:=127.0.0.1
HOST:=localhost
.ONESHELL:

define help
Makefile for running Logstash and Filebeat with Toil

- Install dependencies

make install

- (In a separate terminal session) start Logstash

make logstash-start

- (In a separate terminal session) start Filebeat

make filebeat-start

- Run a Toil workflow in the current session (submits child jobs to LSF HPC)

make run-toil

- Submit the Toil workflow as a leader job to LSF HPC (simluates prod workflow execution on HPC)

make submit-toil

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

# this one has an older unzipped timestamp which messes with make on repeat usages
$(ES_HOME): $(ES_GZ)
	tar -xzf $(ES_GZ) && touch $(ES_HOME)

$(KIBANA_HOME):
	wget "$(KIBANA_URL)" && \
	tar -xzf $(KIBANA_GZ)

$(LS_HOME):
	wget "$(LS_URL)" && \
	tar -xzf $(LS_GZ)

# put system logs for software here
export LOG_DIR:=$(CURDIR)/logs
$(LOG_DIR):
	mkdir -p "$(LOG_DIR)"

# config files for software go here
CONFIG_DIR:=$(CURDIR)/config
$(CONFIG_DIR):
	mkdir -p "$(CONFIG_DIR)"

# install for CWLTool, Toil
install: conda $(ES_HOME) $(KIBANA_HOME) $(LS_HOME) $(LOG_DIR) $(FB_HOME)
	pip install \
	cwltool==3.0.20201203173111 \
	cwlref-runner==1.0 \
	toil[all]==5.2.0
# conda install -y conda-forge::jq # conda-forge::yq <- this one has issues installing...

# interactive shell with environment populated
bash:
	bash







# ~~~~~ Logstash ~~~~~ #
# https://www.elastic.co/guide/en/logstash/current/getting-started-with-logstash.html
# https://www.elastic.co/guide/en/logstash/current/pipeline.html
# https://www.elastic.co/guide/en/logstash/current/configuration.html
# https://www.elastic.co/guide/en/logstash/current/environment-variables.html
# https://www.elastic.co/guide/en/logstash/current/plugins-inputs-jdbc.html
# https://www.elastic.co/guide/en/logstash/current/event-dependent-configuration.html
# https://www.elastic.co/guide/en/logstash/current/plugins-inputs-jdbc.html#plugins-inputs-jdbc-last_run_metadata_path
# https://www.elastic.co/guide/en/logstash/current/advanced-pipeline.html
# config file to use for parsing logs
LS_CONF:=$(CONFIG_DIR)/logstash.conf
LS_HOST:=$(HOST)
# logstash runs on this port
LS_PORT:=9600
# connect to Filebeat on this port; make sure its the same as in FB_CONFIG
LS_FB_PORT:=5044
# dir for logstash system data
LS_DATA:=$(CURDIR)/ls_data

$(LS_DATA):
	mkdir -p "$(LS_DATA)"

# launch a persistent Logstash process in the current session (run it in another terminal)
logstash-start: $(LS_HOME) $(LS_DATA)
	logstash \
	-f "$(LS_CONF)" \
	--path.data "$(LS_DATA)" \
	--path.logs "$(LOG_DIR)" \
	--http.host "$(LS_HOST)" \
	--http.port "$(LS_PORT)" \
	--config.reload.automatic









# ~~~~~ Filebeat ~~~~~ #
# NOTE: Make sure Logstash is running first before you start Filebeat or it wont have anything to connect to!
# https://www.elastic.co/guide/en/beats/filebeat/7.10/filebeat-installation-configuration.html
# https://www.elastic.co/guide/en/beats/filebeat/6.8/filebeat-input-log.html
# https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-starting.html
# demo log file input for filebeat;
# wget https://download.elastic.co/demos/logstash/gettingstarted/logstash-tutorial.log.gz

# local dirs to store data for the software
FB_DATA:=$(CURDIR)/filebeat-data
$(FB_DATA):
	mkdir -p "$(FB_DATA)"

# run filebeat in the current session, but monitor a specific directory for Toil logs and LSF logs
# NOTE: use this one
FB_CONFIG_TOIL:=$(CONFIG_DIR)/filebeat-toil.yml
filebeat-start: $(FB_DATA) $(LOG_DIR)
	filebeat -e \
	-c "$(FB_CONFIG_TOIL)" \
	-E "filebeat.inputs=[{type:log,paths:['$(CURDIR)/runs/*/toil.log']},{type:log,paths:['$(CURDIR)/runs/*/lsf.log']}]" \
	-d "publish" \
	--path.data "$(FB_DATA)" \
	--path.logs "$(LOG_DIR)"






# NOTE: these are other Filebeat recipes for testing, dont actually use them though for the prototype prod method
# demo log file to use for testing Filebeat -> Logstash connection
$(CURDIR)/logstash-tutorial.log:
	wget https://download.elastic.co/demos/logstash/gettingstarted/logstash-tutorial.log.gz && gunzip logstash-tutorial.log.gz

# this is the file that we want Filebeat to ingest
FB_INPUT_LOGFILE:=$(CURDIR)/logstash-tutorial.log
# example template config file; set IP address, ports, here, the input log path will get overwritten
FB_CONFIG_EXAMPLE:=$(CONFIG_DIR)/filebeat-example.yml

# dynamically updated Filebeat config YAML file;
# need to hard-code in the absolute path to the input log file we want to read in, this will be set dynamically at run time
# $ make filebeat-run FB_CONFIG=/path/to/new/filebeat-config.yml FB_INPUT_LOGFILE=/path/to/toil/run.log
# NOTE: dont actually need to do this, you can overwrite the values directly with the -E arg as shown below
FB_CONFIG:=$(CONFIG_DIR)/filebeat.yml
$(FB_CONFIG):$(FB_CONFIG_EXAMPLE)
	sed -e 's|/path/to/logs/logstash-tutorial.log|$(FB_INPUT_LOGFILE)|g' "$(FB_CONFIG_EXAMPLE)" > $(FB_CONFIG)
.PHONY:$(FB_CONFIG)

# interactive filebeat in current session
filebeat-run-int: $(FB_CONFIG) $(FB_DATA) $(LOG_DIR)
	filebeat -e -c "$(FB_CONFIG)" -d "publish" \
	--path.data "$(FB_DATA)" \
	--path.logs "$(LOG_DIR)"

# https://stackoverflow.com/questions/51246296/how-to-specify-inputs-on-command-line
# filebeat -e -E "filebeat.inputs=[{type:log,paths:['/path/to/dir/*']}]"
filebeat-run-oneinput: $(FB_DATA) $(LOG_DIR)
	filebeat -c "$(FB_CONFIG)" \
	-E "filebeat.inputs=[{type:log,paths:['$(FB_INPUT_LOGFILE)']}]" \
	-d "publish" \
	--path.data "$(FB_DATA)" \
	--path.logs "$(LOG_DIR)"




# ~~~~~ ElasticSearch setup ~~~~~ #
# https://www.elastic.co/guide/en/elasticsearch/reference/current/targz.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/important-settings.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/setting-system-settings.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-discovery-settings.html

# this is the default port for ElasticSearch;
export ES_PORT:=9200
# dont acutally use this yet
export ES_HOST:=$(IP)
export ES_URL:=http://$(ES_HOST):$(ES_PORT)
export ES_PIDFILE:=$(CURDIR)/elasticsearch.pid
export ES_DATA:=$(CURDIR)/elasticsearch_data
export ES_INDEX:=log_events
# location of file elasticsearch.yml; elasticsearch-7.10.1/config/elasticsearch.yml
# export ES_PATH_CONF:=$(CONFIG_DIR)
$(ES_DATA):
	mkdir -p "$(ES_DATA)"

# start the ElasticSearch server
# https://stackoverflow.com/questions/14379575/configure-port-number-of-elasticsearch
elasticsearch-start: $(ES_HOME) $(ES_DATA)
	elasticsearch \
	-E "path.data=$(ES_DATA)" \
	-E "path.logs=$(LOG_DIR)" \
	-E "http.port=$(ES_PORT)" \
	-E 'cluster.name=silo-es' \
	-E "node.name=es-1" \
	-E "discovery.type=single-node"

# other settings;
# in daemon mode
# -d -p "$(ES_PIDFILE)"
# network settings; dont touch these until moving to prod
# -E 'cluster.initial_master_nodes=["master"]'
# -E "network.host=$(ES_HOST)"

# NOTE: issues with node clustering for ES on silo;
# https://stackoverflow.com/questions/37970187/elasticsearch-cluster-master-not-discovered-exception
# [2021-05-20T13:42:44,076][WARN ][o.e.b.BootstrapChecks    ] [silo] the default discovery settings are unsuitable for production use; at least one of [discovery.seed_hosts, discovery.seed_providers, cluster.initial_master_nodes] must be configured
#
# https://discuss.elastic.co/t/how-my-config-file-should-be-on-publish-mode-with-a-single-node/189034/9

# stop ElasticSearch daemon
# elasticsearch-stop:
# 	pkill -F "$(ES_PIDFILE)"

# make the index where we will store log events
# NOTE: by default ElasticSearch should auto-create a missing index which is being published to by Logstash, etc..
elasticsearch-create-index:
	curl -X PUT "$(ES_URL)/$(ES_INDEX)?pretty"

# check if ElasticSearch is running
elasticsearch-check:
	curl -X GET "$(ES_URL)/?pretty"

# get the entries in the ElasticSearch index
elasticsearch-count:
	curl  "$(ES_URL)/$(ES_INDEX)/_count?pretty=true"

elasticsearch-search:
	curl  "$(ES_URL)/$(ES_INDEX)/_search?pretty=true"

# sometimes need to clear out old ElasticSearch data in order to restart with fresh settings e.g. for clustering..
elasticsearch-clean:
	rm -rf "$(ES_HOME)" "$(ES_DATA)"


# ~~~~~ RUN WORKFLOW ~~~~~ #
# get a unique ID for each run
RUN_ID:=$(shell date +%s)
# dir to run the workflow in
RUN_DIR:=$(CURDIR)/runs/$(RUN_ID)
$(RUN_DIR):
	mkdir -p "$(RUN_DIR)"

WORK_DIR:=$(RUN_DIR)/work
TMP_DIR:=$(WORK_DIR)/tmp
$(WORK_DIR):
	mkdir -p "$(WORK_DIR)"
$(TMP_DIR):
	mkdir -p "$(TMP_DIR)"


# run the workflow
run-cwltool:
	cwl-runner workflow.cwl

# run Toil workflow, submit child jobs to LSF HPC
TOIL_LOG:=$(RUN_DIR)/toil.log
TOIL_STDOUT_LOG:=$(RUN_DIR)/toil.stdout.log
TOIL_CLUSTERSTATS:=$(RUN_DIR)/toil_cluster.json
run-toil: $(RUN_DIR) $(WORK_DIR) $(TMP_DIR)
	set -eu -o pipefail
	toil-cwl-runner \
	--batchSystem lsf \
	--retryCount 1 \
	--disableCaching True \
	--disable-user-provenance \
	--disable-host-provenance \
	--clean onSuccess \
	--cleanWorkDir onSuccess \
	--writeLogs "$(RUN_DIR)" \
	--writeLogsFromAllJobs \
	--logFile "$(TOIL_LOG)" \
	--workDir "$(WORK_DIR)" \
	--tmpdir-prefix "$(TMP_DIR)" \
	--clusterStats "$(TOIL_CLUSTERSTATS)" \
	workflow.cwl 2>&1 | tee "$(TOIL_STDOUT_LOG)"

# make a script file to submit the parent leader job to LSF
SUB_SCRIPT:=job.sh
.PHONY: $(SUB_SCRIPT)
$(SUB_SCRIPT):
	echo '#!/bin/bash' > $(SUB_SCRIPT)
	echo 'cd $(CURDIR)' >> $(SUB_SCRIPT)
	echo 'make run-toil RUN_ID=$(RUN_ID)' >> $(SUB_SCRIPT)

# submit the parent leader job to LSF
LSF_LOG:=$(RUN_DIR)/lsf.log
submit-toil: $(SUB_SCRIPT) $(RUN_DIR)
	bsub -oo "$(LSF_LOG)" < $(SUB_SCRIPT)









# start Filebeat before starting Toil; point Filebeat to the Toil log to load; kill Filebeat when Toil finishes
# NOTE: dont use this method, use submit-toil with a separate persistent Filebeat process instead
FB_RUN_LOG:=$(RUN_DIR)/filebeat_log
FB_RUN_PID:=$(RUN_DIR)/filebeat.pid
FB_RUN_DATA:=$(RUN_DIR)/filebeat_data
run-toil-filebeat: $(RUN_DIR) $(WORK_DIR) $(TMP_DIR)
	set -eu -o pipefail
	# start Filebeat in the Run dir and push it to the background; record the pid
	filebeat -c "$(FB_CONFIG)" \
	-E "filebeat.inputs=[{type:log,paths:['$(TOIL_LOG)']}]" \
	-d "publish" \
	--path.data "$(FB_RUN_DATA)" \
	--path.logs "$(FB_RUN_LOG)" & pid="$$!" ; echo "$$pid" > "$(FB_RUN_PID)"
	echo ">>> Filebeat ($$pid) running at $(RUN_DIR)"
	# pause for Filebeat to start running...
	sleep 10
	# kill Filebeat when everything finishes
	trap "echo '>>> killing Filebeat in $(RUN_DIR)' ; cat $(FB_RUN_PID) | xargs kill ; sleep 3" EXIT TERM INT
	# run Toil
	echo ">>> Starting Toil run in $(RUN_DIR)"
	toil-cwl-runner \
	--batchSystem lsf \
	--retryCount 1 \
	--disableCaching True \
	--disable-user-provenance \
	--disable-host-provenance \
	--clean onSuccess \
	--cleanWorkDir onSuccess \
	--writeLogs "$(RUN_DIR)" \
	--writeLogsFromAllJobs \
	--logFile "$(TOIL_LOG)" \
	--workDir "$(WORK_DIR)" \
	--tmpdir-prefix "$(TMP_DIR)" \
	workflow.cwl 2>&1 | tee "$(TOIL_STDOUT_LOG)"
	echo ">>> Toil run finished in $(RUN_DIR)"


clean:
	rm -rf "$(WORK_DIR)"
