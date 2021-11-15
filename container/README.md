## Logstash Server

#### Build SIF

```
sudo -E singularity build logstash_service.sif logstash_service.def
```

#### Expected Instance Run Variables

Here are the essential environment variables needed by the instance

> Note: Singularity passes environment variables to the SIF container by prepending variable names with
> `SINGULARITYENV_`. For example, to set `RIDGEBACK_PORT` in the container, you must set
> `SINGULARITYENV_RIDGEBACK_PORT`.

##### General

| Variable                            | Description                                                         |
| :---------------------------------- | :------------------------------------------------------------------ |
| SINGULARITYENV_TOIL_WORK_PATH       | The path containing TOIL log files                                  |
| SINGULARITYENV_SINCEDB_PATH         | SINCEDB file creation path to track log files read                  |
| SINGULARITYENV_PATTERNS_PATH        | Path to the pattern folder in this repo                             |
| SINGULARITYENV_ELASTIC_SEARCH_URL   | Url to connect to elasticsearch, must include credentials if needed |
| SINGULARITYENV_LOGSTASH_CONFIG_PATH | Config for logstash, located in the config folder in this repo      |
| SINGULARITYENV_LOGSTASH_DATA_PATH   | path to DATA directory created by logstash                          |
| SINGULARITYENV_LOGSTASH_LOG_PATH    | path to a log file created by logstash                              |
| SINGULARITYENV_LOGSTASH_HTTP_HOST   | logstash server host                                                |
| SINGULARITYENV_LOGSTASH_HTTP_PORT   | logstash server port                                                |

#### Configure singularity mount points

Since we will be running our instance in a singularity container, we need to make sure it has the right paths mounted to work properly. Running the following command will mount /juno

```
export SINGULARITY_BIND="/juno"
```

#### Running an instance

Running the following command will create a logstash instance named `logstash_service`

```
singularity instance start logstash_service.sif logstash_service
```
