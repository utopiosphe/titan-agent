#!/usr/bin/expect -f

# 启动 virsh console 连接到虚拟机 Painet
spawn /usr/bin/virsh console Painet

# 设置超时时间（秒）
set timeout -1

# 捕获控制台的输出并做出相应处理
expect {
    # 当输出包含 "Connected to domain" 时，发送回车键
    "Connected to domain" {
        send "\r"
        exp_continue
    }

    # 当输出包含 "PaiNetwork:" 时，结束会话
    "login" {
        #send_user "Found 'PaiNetwork:', exiting...\n"
        exit
    }
}

# 关闭 expect 进程
expect eof

