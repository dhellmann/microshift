*** Settings ***
Library    Process
Library    SSHLibrary
Library    String


*** Keywords ***
Get Systemd Setting
    [Arguments]  ${unit_name}  ${property}
    Open Connection    ${USHIFT_IP}
    Login    ${USHIFT_USER}    allow_agent=True
    ${stdout}    ${rc}=    Execute Command
    ...    systemctl show --property=${property} ${unit_name}
    ...    sudo=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Be Empty    ${stdout}
    Close Connection
    ${value}=  Fetch From Right  ${stdout}  =
    ${result}=  Strip String  ${value}
    RETURN  ${result}
