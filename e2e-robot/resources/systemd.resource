*** Settings ***
Library    Process
Library    SSHLibrary
Library    String


*** Keywords ***
Get Systemd Setting
    [Documentation]  Fetch one setting from systemd for the named unit.
    ...  Take care to get the unit_name value _exactly_ right, or
    ...  systemd will report a default value without reporting any error
    ...  or warning.
    [Arguments]  ${unit_name}  ${property}

    Open Connection    ${USHIFT_IP}
    Login    ${USHIFT_USER}    allow_agent=True

    ${stdout}    ${rc}=    Execute Command
    ...    systemctl show --property=${property} ${unit_name}
    ...    sudo=True    return_rc=True
    Should Be Equal As Integers    ${rc}    0
    Should Not Be Empty    ${stdout}
    Close Connection

    # stdout will have NameOfProperty=value but we only want to return
    # the value, so parse it out
    ${value}=  Fetch From Right  ${stdout}  =
    ${result}=  Strip String  ${value}
    RETURN  ${result}


Systemctl
    [Documentation]  Run a systemctl command on the microshift host.
    ...  The intent is to start, stop, or restart a service. Other
    ...  commands should be implemented separately.  When the verb is
    ...  "start" or "restart", this keyword will wait for the unit
    ...  to report that it is "running". When the verb is "stop", this
    ...  keyword will wait for the unit to report that it is "dead".
    [Arguments]  ${verb}  ${unit_name}

    Open Connection    ${USHIFT_IP}
    Login    ${USHIFT_USER}    allow_agent=True

    ${stdout}  ${rc}=  Execute Command
    ...    systemctl ${verb} ${unit_name}
    ...    sudo=True  return_rc=True
    #Should Be Equal As Integers  0  ${rc}

    # It takes a bit for systemd to respond, and if we check too soon
    # then it looks like microshift is up, even though it is about to
    # be restarted.
    Sleep    5s

    IF  "${verb}" in {"restart", "start"}
        ${state}=  Set Variable  running
    ELSE
        ${state}=  Set Variable  dead
    END

    Wait Until Keyword Succeeds
    ...    10x
    ...    10s
    ...    Execute Command
    ...    [ $(systemctl show -p SubState --value ${unit_name}) = ${state} ]
    ...    timeout=10s    return_stdout=True    return_stderr=True

    Close Connection
