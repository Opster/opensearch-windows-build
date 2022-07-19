 param ($java_home)

function Print-Help {
    Write-Output "./install-service-opster-metricbeat.ps1 -opster_host <opster-host> -opster_token <opster-token> -es_url <es-url-monitored> -es_user <elasticsearch auth user (optional)> -es_password <elasticsearch auth password (optional)>"
}

function create-temp-folder {
	if (!(Test-Path "C:\temp")){
		New-Item -itemType Directory -Path C:\ -Name temp
	}
}

function clean-old-install {
	rm -r "C:\Program Files\opensearch"
	rm -r "C:\Program Files\opensearch-dashboard"
}

function get-opensearch {
	create-temp-folder
	wget https://opensearch-win.s3.amazonaws.com/opensearch-with-democerts.zip -o c:\temp\opensearch.zip
	Expand-Archive -LiteralPath C:\temp\opensearch.zip -DestinationPath  C:\temp\
	New-Item -Path "C:\Program Files" -Name "opensearch" -ItemType "directory"
	Copy-Item -Path "C:\temp\opensearch-build\opensearch\*" -Destination "C:\Program Files\opensearch" -Recurse 
}

function get-opensearch-dashboard {
	create-temp-folder
	wget https://opensearch-win.s3.amazonaws.com/opensearch-dashboards-2.0.0-SNAPSHOT-windows-x64.zip -o c:\temp\opensearch-dashboard.zip
	Expand-Archive -LiteralPath c:\temp\opensearch-dashboard.zip -DestinationPath  C:\temp\
	New-Item -Path "C:\Program Files" -Name "opensearch-dashboard" -ItemType "directory"
	Copy-Item -Path "C:\temp\opensearch-dashboards-2.0.0-SNAPSHOT-windows-x64\*" -Destination "C:\Program Files\opensearch-dashboard" -Recurse
}

function get-opensearch-dashboard-plugins {
	create-temp-folder
	wget https://opensearch-win.s3.amazonaws.com/dashboard-plugins.zip -o c:\temp\opensearch-dashboard-plugins.zip
	Expand-Archive -LiteralPath c:\temp\opensearch-dashboard-plugins.zip -DestinationPath  C:\temp\
}


function extract-components {
	Expand-Archive -LiteralPath 'C:\temp\' -DestinationPath C:\temp
}

function clean-temp {
	rm -r C:\temp
}
clean-old-install
clean-temp
get-opensearch
get-opensearch-dashboard
get-opensearch-dashboard-plugins


# Delete and stop the service if it already exists.
if (Get-Service opensearch-dashboard -ErrorAction SilentlyContinue) {
  $service = Get-WmiObject -Class Win32_Service -Filter "name='opensearch-dashboard'"
  $service.StopService()
  Start-Sleep -s 1
  $service.delete()
}
$workdir = Split-Path $MyInvocation.MyCommand.Path
$opensearch_home = "C:\Program Files\opensearch"
$opensrarch_dashboard_home = "C:\Program Files\opensearch-dashboard"

if($java_home -eq $null)
{
  [System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\opensearch\jdk', 'Machine')
}
else
{
  [System.Environment]::SetEnvironmentVariable('JAVA_HOME', $java_home, 'Machine')
}
exit 0
#Write-Output "Found opensearch home @ $opensearch_home"
$opensearch_bat = "$opensearch_home\bin\opensearch-service.bat install opensearch"
Start-Process -FilePath "C:\Program Files\opensearch\bin\opensearch-service.bat" -Wait -ArgumentList "install"

#Start-Sleep -s 5
#Start-Service opensearch

# Create the new service.
New-Service -name opensearch-dashboard `
  -displayName opensearch-dashboard `
  -binaryPathName "`"C:\Program Files\opensearch-dashboard\bin\opensearch-dashboard.bat`""

# Attempt to set the service to delayed start using sc config.
Try {
  Start-Process -FilePath sc.exe -ArgumentList 'config opensearch-dashboard start= delayed-auto'
}
Catch { Write-Host -f red "An error occured setting the service to delayed start." }
#Start-Sleep -s 2

