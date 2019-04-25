#!/bin/bash

#####################################################################
# Example command arguments
# deploy.sh --ingressdns "" --postgresjdbcurl "" --acrname "" --acrkey "" --giturl ""
#   
#####################################################################
# user defined parameters
INGRESSDNS=""
POSTGRESJDBCURL="" 
JENKINSPASSWORD="kube123"
ACRNAME=""
ACRKEY=""
HELMRELEASENAME="myapp"
APPK8SNS="myapp"
GITURL=""
GITBRANCH="master"

while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --ingressdns)
      INGRESSDNS="$1"
      shift
      ;;
    --postgresjdbcurl)
      POSTGRESJDBCURL="$1"
      shift
      ;;
    --acrname)
      ACRNAME="$1"
      shift
      ;;
    --acrkey)
      ACRKEY="$1"
      shift
      ;;
    --helmreleasename)
      HELMRELEASENAME="$1"
      shift
      ;;
    --appk8sns)
      APPK8SNS="$1"
      shift
      ;;
    --giturl)
      GITURL="$1"
      shift
      ;;
    --gitbranch)
      GITBRANCH="$1"
      shift
      ;;
    --jenkinspassword)
      JENKINSPASSWORD="$1"
      shift
      ;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
done


function throw_if_empty() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Parameter '$name' cannot be empty." 1>&2
    exit -1
  fi
}

#check parametrs
throw_if_empty --ingressdns $INGRESSDNS
throw_if_empty --postgresjdbcurl $POSTGRESJDBCURL
throw_if_empty --acrname  $ACRNAME
throw_if_empty --acrkey $ACRKEY
throw_if_empty --helmreleasename $HELMRELEASENAME
throw_if_empty --appk8sns $APPK8SNS
throw_if_empty --giturl $GITURL
throw_if_empty --gitbranch $GITBRANCH
throw_if_empty --jenkinspassword $JENKINSPASSWORD

#####################################################################
# constants
JENKINSJOBNAME="01-MYAPP"
JENKINS_USER="admin"
JENKINSSERVICENAME="myjenkins001"

#####################################################################
# internal variables
JENKINS_KEY=""
REGISTRY_SERVER=""
REGISTRY_USER_NAME=""
REGISTRY_PASSWORD=""
ACRSERVER="${ACRNAME}.azurecr.io"
CREDENTIALS_ID="${ACRSERVER}"
CREDENTIALS_DESC="${ACRSERVER}"

#############################################################
# supporting functions
#############################################################
function retry_until_successful {
    counter=0
    echo "      .. EXEC:" "${@}"
    "${@}"
    while [ $? -ne 0 ]; do
        if [[ "$counter" -gt 50 ]]; then
            exit 1
        else
            let counter++
        fi
        echo "Retrying ..."
        sleep 5
        "${@}"
    done;
}

function run_cli_command {
    >&2 echo "      .. Running \"$1\"..."
    if [ -z "$2" ]; then
        retry_until_successful kubectl exec ${KUBE_JENKINS} -- java -jar  /var/jenkins_home/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080 -auth "${JENKINS_USER}":"${JENKINS_KEY}" $1
    else
        retry_until_successful kubectl cp "$2" ${KUBE_JENKINS}:/tmp/tmp.xml
        tmpcmd="cat /tmp/tmp.xml | java -jar  /var/jenkins_home/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080 -auth \"${JENKINS_USER}\":\"${JENKINS_KEY}\" $1"
        tmpcmd="${tmpcmd//'('/'\('}"
        tmpcmd="${tmpcmd//')'/'\)'}"
        echo "${tmpcmd}" > mycmd
        retry_until_successful kubectl cp mycmd ${KUBE_JENKINS}:/tmp/mycmd
        retry_until_successful kubectl exec ${KUBE_JENKINS} -- sh /tmp/mycmd
        retry_until_successful kubectl exec ${KUBE_JENKINS} -- rm /tmp/mycmd
        retry_until_successful kubectl exec ${KUBE_JENKINS} -- rm /tmp/tmp.xml
        rm mycmd
    fi
}

#echo "          .. patching tiller-deploy"
#retry_until_successful kubectl -n kube-system patch deployment tiller-deploy -p '{"spec": {"template": {"spec": {"automountServiceAccountToken": true}}}}'

#############################################################
# jenkins installation / configuration
#############################################################

echo "  .. helming jenkins"
### install jenkins to kubernetes cluster
retry_until_successful helm install --name ${JENKINSSERVICENAME} stable/jenkins --set "master.adminPassword=${JENKINSPASSWORD}" >/dev/null

echo "  .. installing jenkins"

echo "      .. waiting for pods"

### get node name
echo -n "         ."
KUBE_JENKINS=""
while [  -z "$KUBE_JENKINS" ]; do
    echo -n "."
    sleep 3
    KUBE_JENKINS=$(kubectl get pods | grep "${JENKINSSERVICENAME}\-" | grep "Running" | awk '{print $1;}')
    if [ -z "${KUBE_JENKINS}" ]; then
    	KUBE_JENKINS=$(kubectl get pods | grep "\${JENKINSSERVICENAME}\-" | grep "CrashLoopBackOff" | awk '{print $1;}')
	if [ -n "${KUBE_JENKINS}" ]; then
	    helm del --purge ${JENKINSSERVICENAME}
	    sleep 10
            helm install --name ${JENKINSSERVICENAME} stable/jenkins --set "master.adminPassword=${JENKINSPASSWORD}" 
	fi
    	KUBE_JENKINS=""
    fi
done
echo ""

echo "      .. configuring jenkins"
### get jenkins token
JENKINS_KEY=""
echo -n "         .. get key "
while [  -z "$JENKINS_KEY" ]; do
    echo -n "."
    sleep 5
    retry_until_successful kubectl exec ${KUBE_JENKINS} -- curl -D - -s -k -X POST -c /tmp/cook.txt -b /tmp/cook.txt -d j_username=${JENKINS_USER} -d j_password=${JENKINSPASSWORD} http://localhost:8080/j_security_check &>/dev/null
    JENKINS_CRUMB=$(kubectl exec ${KUBE_JENKINS} -- curl -D - -s -k -c /tmp/cook.txt -b /tmp/cook.txt http://localhost:8080/me/configure | grep "crumb.init" | sed -n 's/.*crumb.init.\(.*\)\/>.*/\1/p' | sed -n 's/.*, \"\([0-9abcdef]*\)\".*/\1/p' 2>/dev/null)
    JENKINS_KEY=$(kubectl exec ${KUBE_JENKINS} -- curl -D - -s -k -c /tmp/cook.txt -X POST -b /tmp/cook.txt  localhost:8080/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken -H "Content-Type: application/x-www-form-urlencoded" -H "Jenkins-Crumb: ${JENKINS_CRUMB}" | sed -n 's/.*tokenValue\"\:\"\([0-9abcdef]*\)\".*/\1/p' 2>/dev/null)
done
echo -n "${JENKINS_KEY}"
echo ""

kubectl exec ${KUBE_JENKINS} -- cat /var/jenkins_home/config.xml > /tmp/config.xml
sed -i.bak s/kubernetes.default/kubernetes.default.svc/g /tmp/config.xml
kubectl cp /tmp/config.xml ${KUBE_JENKINS}:/var/jenkins_home/config.xml

### install jenkins plugins
run_cli_command "install-plugin pipeline-utility-steps -deploy"
run_cli_command "install-plugin http_request -deploy"
UPDATE_LIST=$(run_cli_command "list-plugins" | grep -e ')$' | awk '{ print $1 }' );
if [ ! -z "${UPDATE_LIST}" ]; then
    run_cli_command "install-plugin ${UPDATE_LIST}"
fi
run_cli_command "safe-restart"
sleep 30

### create secrets for ACR

credentials_xml=$(cat <<EOF
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>{insert-credentials-id}</id>
  <description>{insert-credentials-description}</description>
  <username>{insert-user-name}</username>
  <password>{insert-user-password}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF
)

#add user/pwd
credentials_xml=${credentials_xml//'{insert-credentials-id}'/${CREDENTIALS_ID}}
credentials_xml=${credentials_xml//'{insert-credentials-description}'/${CREDENTIALS_DESC}}
credentials_xml=${credentials_xml//'{insert-user-name}'/${ACRNAME}}
credentials_xml=${credentials_xml//'{insert-user-password}'/${ACRKEY}}
echo "${credentials_xml}" > tmp.xml
run_cli_command 'create-credentials-by-xml SystemCredentialsProvider::SystemContextResolver::jenkins (global)' "tmp.xml"
rm tmp.xml

### importing job for myapp
######################################
job_xml=$(cat <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.13">
  <actions/>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>acr</name>
          <description></description>
          <defaultValue>{acr}</defaultValue>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>giturl</name>
          <description></description>
          <defaultValue>{giturl}</defaultValue>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>gitbranch</name>
          <description></description>
          <defaultValue>{gitbranch}</defaultValue>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>releasename</name>
          <description></description>
          <defaultValue>{releasename}</defaultValue>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>appns</name>
          <description></description>
          <defaultValue>{appns}</defaultValue>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>ingressdns</name>
          <description></description>
          <defaultValue>{ingressdns}</defaultValue>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers/>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.40">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@3.4.0">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>{giturl}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/{gitbranch}</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>module05/jenkins/Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
)

job_xml=${job_xml//'{acr}'/${ACRSERVER}}
job_xml=${job_xml//'{giturl}'/${GITURL}}
job_xml=${job_xml//'{gitbranch}'/${GITBRANCH}}
job_xml=${job_xml//'{releasename}'/${HELMRELEASENAME}}
job_xml=${job_xml//'{ingressdns}'/${INGRESSDNS}}
job_xml=${job_xml//'{appns}'/${APPK8SNS}}
echo "${job_xml}" > tmp.xml
run_cli_command "create-job ${JENKINSJOBNAME}" "tmp.xml"
rm tmp.xml

#############################################################
# configure kubernetes credentials
#############################################################

echo "  .. create namespace"
### create namespace
kubectl create namespace ${APPK8SNS}

echo "  .. install kubernetes security assets"
### create secrets (which will be used by helm install later on)
kubectl create secret generic ${HELMRELEASENAME}-myapp --from-literal=postgresqlurl="${POSTGRESJDBCURL}" --namespace ${APPK8SNS}

# Jenkins system acount
kubectl create clusterrolebinding jenkinsdefault --clusterrole cluster-admin --serviceaccount=default:default

#############################################################
# wait for jenkins public IP
#############################################################

echo "  .. waiting for jenkins public IP"
echo -n "     ."
JENKINS_IP=""
while [  -z "$JENKINS_IP" ]; do
    echo -n "."
    sleep 3
    JENKINS_IP=$(kubectl describe service ${JENKINSSERVICENAME} | grep "LoadBalancer Ingress:" | awk '{print $3}')
done
echo ""

echo "##########################################################################"
echo "### DONE!"
echo "### now you can login to JENKINS at http://${JENKINS_IP}:8080 with username: ${JENKINS_USER} , password: ${JENKINSPASSWORD}"
echo "### URL for your application is http://${APPFQDN} after deployment"
