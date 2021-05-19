#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow
doc: Demo CWL workflow that can be run with CWLTool or Toil. This workflow will spawn some child jobs that echo some text into a file and then runs a couple sleep commands in parallel. Workflow does not require any inputs and has no outputs.

requirements:
    MultipleInputFeatureRequirement: {}
    SubworkflowFeatureRequirement: {}
    InlineJavascriptRequirement: {}
    StepInputExpressionRequirement: {}

inputs:
  sampleid:
    type: string
    default: "Sample1"

outputs: []
  # output_file:
  #   type: File
  #   outputSource: echo/output_file

steps:
  echo:
    in:
      echo_string: sampleid
    out: [ output_file ]
    run:
      class: CommandLineTool
      baseCommand: ['echo']
      stdout: output.txt
      inputs:
        echo_string:
          type: string
          inputBinding:
            position: 1
      outputs:
        output_file:
          type: stdout
  sleep1:
    in:
      dummy_file: echo/output_file
    out: []
    run:
      class: CommandLineTool
      baseCommand: ['sleep', '5']
      inputs:
        dummy_file: File
      outputs: []
  sleep2:
    in:
      dummy_file: echo/output_file
    out: []
    run:
      class: CommandLineTool
      baseCommand: ['sleep', '5']
      inputs:
        dummy_file: File
      outputs: []
