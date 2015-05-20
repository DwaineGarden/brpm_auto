################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2014
# All Rights Reserved.
################################################################################
#---------------------- f2_directExecute -----------------------#
# Description: Direct execute on the command line
#=> About the f2 framework: upon loading the automation, several utility classes will be available
#   @rpm: the BrpmAutomation class, @p: the Param class, @rest: the BrpmRest class and 
#   @transport: the Transport class - the transport class will be loaded dependent on the SS_transport property value (ssh, nsh or baa) 

#---------------------- Arguments --------------------------#
###
# username:
#   name: username
#   position: A1:F1
#   required: true
#   type: in-text
# password:
#   name: password
#   private: yes
#   required: true
#   position: A2:D2
#   type: in-text
# non_primary_group:
#   name: Group other than home group
#   position: A3:D3
#   type: in-text
###

#---------------------- Declarations -----------------------#
params["direct_execute"] = true #Set for local execution
pwd = params["password"]
user = params["username"]
non_primary_group = params["non_primary_group"]
group_stg = ""

#---------------------- Main Body --------------------------#
# Check if we have been passed a package id from a promotion
group = "-G #{non_primary_group} " if !non_primary_group.nil? && non_primary_group.length > 2
cmd = "useradd -p #{pwd.crypt("JU")} #{group}#{user}"
result = run_command(params, cmd,"")


