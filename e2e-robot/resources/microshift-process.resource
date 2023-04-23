*** Settings ***
Library    Process
Library    SSHLibrary
Library    String
Library    OperatingSystem
Resource    ../resources/systemd.resource
Library    ../resources/YAML.py


*** Keywords ***
MicroShift Version
    [Documentation]    Run the version command
    Open Connection    ${USHIFT_IP}
    Login    ${USHIFT_USER}    allow_agent=True
    ${version_text}    ${rc}=    Execute Command
    ...    microshift version -o yaml
    ...    sudo=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Be Empty    ${version_text}
    Close Connection
    ${version}=  Yaml Parse  ${version_text}
    RETURN  ${version}


Parse Version Line
    [Arguments]  ${line}
    ${version_raw}=  Fetch From Right  ${line}  :
    ${version}=  Strip String  ${version_raw}
    RETURN  ${version}


Restart MicroShift
    [Documentation]  Restart the MicroShift service
    Systemctl  restart  microshift


Clear MicroShift Config
    [Documentation]  Remove any configuration file
    Open Connection    ${USHIFT_IP}
    Login    ${USHIFT_USER}    allow_agent=True
    ${stdout}  ${rc}=  Execute Command
    ...    rm -f /etc/microshift/config.yaml
    ...    sudo=True  return_rc=True
    Should Be Equal As Integers  0  ${rc}
    Close Connection


Upload MicroShift Config
    [Documentation]  Upload a new configuration file to the MicroShift host
    [Arguments]  ${config_content}

    Log  ${config_content}

    ${rand}=    Generate Random String
    ${local_tmp}=    Join Path    /tmp    ${rand}
    Create File    ${local_tmp}    ${config_content}

    Open Connection    ${USHIFT_IP}
    Login    ${USHIFT_USER}    allow_agent=True
    ${rand}=    Generate Random String
    ${remote_tmp}=    Join Path    /tmp    ${rand}
    Put File  ${local_tmp}  ${remote_tmp}  mode=0644

    Remove File  ${local_tmp}

    ${stdout}  ${rc}=  Execute Command
    ...    mv ${remote_tmp} /etc/microshift/config.yaml
    ...    sudo=True  return_rc=True
    Should Be Equal As Integers  0  ${rc}

    ${stdout}  ${rc}=  Execute Command
    ...    chown root:root /etc/microshift/config.yaml
    ...    sudo=True  return_rc=True
    Should Be Equal As Integers  0  ${rc}

    Close Connection
