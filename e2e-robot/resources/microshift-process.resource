*** Settings ***
Library    Process
Library    SSHLibrary
Library    String
Library    OperatingSystem


*** Keywords ***
MicroShift Version
    [Documentation]    Run the version command
    Open Connection    ${USHIFT_IP}
    Login    ${USHIFT_USER}    allow_agent=True
    ${version_text}    ${rc}=    Execute Command
    ...    microshift version
    ...    sudo=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Be Empty    ${version_text}
    Close Connection
    ${microshift_version_line}=  Get Line  ${version_text}  0
    ${microshift_version}=  Parse Version Line  ${microshift_version_line}
    ${ocp_version_line}=  Get Line  ${version_text}  0
    ${ocp_version}=  Parse Version Line  ${ocp_version_line}
    ${version}=  Create Dictionary  microshift=${microshift_version}  ocp=${ocp_version}  raw=${version_text}
    RETURN  ${version}


Parse Version Line
    [Arguments]  ${line}
    ${version_raw}=  Fetch From Right  ${line}  :
    ${version}=  Strip String  ${version_raw}
    RETURN  ${version}
