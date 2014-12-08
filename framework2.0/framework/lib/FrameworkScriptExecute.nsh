#!/bin/nsh
# Bradford Byrd (c)BMC Software

RPM_APPLICATION="${1}"
RPM_COMPONENT="${2}"
RPM_ENVIRONMENT="${3}"
RPM_VERSION="${4}"
RPM_REQUEST="${5}"
RPM_CHANNEL_ROOT="${6}"
RPM_SCRIPT_NAME="${7}"

cur_date="AT: `date +%Y%m%d%H%M%S`"

echo "#------------- Executing Script via NSH ---------------#"
echo $cur_date
echo "#=> Params:"
echo "SCRIPT_NAME => $RPM_SCRIPT_NAME"
echo "SCRIPT_DIRECTORY => $RPM_CHANNEL_ROOT"
echo "RPM_APPLICATION => $RPM_APPLICATION"
echo "RPM_COMPONENT => $RPM_COMPONENT"
echo "RPM_ENVIRONMENT => $RPM_ENVIRONMENT"
echo "RPM_VERSION => $RPM_VERSION"

echo Change directory: $RPM_CHANNEL_ROOT
cd $RPM_CHANNEL_ROOT
chmod 755 $RPM_SCRIPT_NAME
nexec -e $RPM_CHANNEL_ROOT/$RPM_SCRIPT_NAME
