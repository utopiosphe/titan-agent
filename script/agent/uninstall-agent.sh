#!/bin/bash

uninstall_titan_agent() {
    systemctl stop titan-agent
    systemctl disable titan-agent
    rm /etc/systemd/system/titan-agent.service
    rm -rf /usr/local/titan-agent
}

{
    uninstall_titan_agent
}