#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

### Setup directories needed for execution
#############################################################################

# Validate the number of arguments
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <machine_name> <pkey> <dma_source_id> <dma_manual_id> <outputPath>"
    exit 1
fi

# Inputs
machine_name=$1
pkey=$2
dmaSourceId=$3
dmaManualId=$4
outputPath=$5

# Function to echo log messages
function writeLog() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Output headers
headers='pkey|dma_source_id|dma_manual_id|machine_name|physical_cpu_count|logical_cpu_count|total_os_memory_mb|total_size_bytes|used_size_bytes'
echo "$headers" > "$outputPath"

# Only supported locally.

# Check if machineName is "localhost"
if [ "$machine_name" = "localhost" ]; then
    machine_name=$(hostname)
fi

if [ "$machine_name" != "$(hostname)" ]; then    
    echo "Specified machine_name ${machine_name} does not match the actual hostname. Writing headers only to $outputPath."
    csvData="\"$pkey\"|\"$dmaSourceId\"|\"$dmaManualId\"|\"$machine_name\"|0|0|0|0|0"
    echo "$csvData" >> "$outputPath"
    exit 0
fi

# Main script logic
writeLog "Fetching machine HW specs from computer: $machine_name and storing it in output: $outputPath"

# Get hardware specifications
physicalCpuCount=$(lscpu | awk '/^Socket/{print $2}')
logicalCpuCount=$(lscpu | awk '/^Thread/{print $4}')
memoryMB=$(free -b | awk '/^Mem/{print ($2+0) / (1024*1024)}')
totalSizeBytes=$(df --total / | awk '/total/{printf("%.0f\n", ($2+0) * 1024)}')
usedSizeBytes=$(df --output=used -B1 / | awk 'NR==2{printf("%.0f\n", ($1+0))}')

# Writing result to output
csvData="\"$pkey\"|\"$dmaSourceId\"|\"$dmaManualId\"|\"$machine_name\"|$physicalCpuCount|$logicalCpuCount|$memoryMB|$totalSizeBytes|$usedSizeBytes"
echo "$csvData" >> "$outputPath"

writeLog "Successfully fetched machine HW specs of $machine_name to output: $outputPath"
