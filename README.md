# toil-elk

Template repo for running Toil on LSF HPC with ELK stack logging

This is a prototype for methods for using ELK stack (ElasticSearch, Logstash, Kibana) + Filebeat in order to track logs from Toil CWL workflow runs on an HPC system (e.g. LSF).

The use case for this is when you want to collect logs for CWL workflows running on the HPC by submitting "leader jobs" which start running a CWL workflow inside of an HPC job, which then submits more child jobs to the HPC as well. In this case, the log files will be located on the HPC's shared filesystem, but your ELK stack components could be located anywhere on the network and not necessarily have access to the HPC's file system. To overcome this limitation, Filebeat is used locally on the HPC to detect and ingest Toil CWL logs and "ship" them to ELK stack over the network interface for further processing.

# Usage

Clone this repo

```
git clone git@github.com:stevekm/toil-elk.git
cd toil-elk
```

Install dependencies

```
make install
```

- this will download & extract pre-compiled binaries for the ELK stack software, and set up a `conda` installation in the local directory to hold the Python dependencies for running Toil.

In separate terminal sessions (or `screen` windows), start ElasticSearch, Logstash, and Filebeat

```
make elasticsearch-start

make logstash-start

make filebeat-start
```

Finally, you can submit a Toil workflow using the included `workflow.cwl` to the LSF cluster with

```
make submit-toil
```

Alternatively, you can run the same Toil workflow in the current session with

```
make run-toil
```

If you keep an eye on your running Logstash process, you should see the log events being displayed in the console (one per line in each log file).

To verify that Logstash events are being propagated to ElasticSearch, you can use the included recipes;

```
make elasticsearch-count

make elasticsearch-search
```

# Methods

CWL workflows are configured to run in the local `runs` directory created by the `run-toil` recipe. Filebeat will be monitoring this directory tree for log files named `lsf.log` and `toil.log`, and will send their contents to Logstash. From there, Logstash is able to apply any log event parsing logic and forward the entries to ElasticSearch for usage with Kibana, etc..

## Notes

- make sure that other instances of Logstash, ElasticSearch, etc., are not already running on the ports specified in the Makefile and config files

- ElasticSearch saves server node clustering information in the data directory (`elasticsearch_data` configured here) which might need to be cleared if config changes are made later

- Logstash does not currently have any log event filter methods applied

- see the `Makefile` contents for all the commands being run along with extra notes and resources where applicable

## To Do

- Currently, log events saved in ElasticSearch are overwriting each other since they do not have a unique `id`; need to update Logstash config to create and apply this.
