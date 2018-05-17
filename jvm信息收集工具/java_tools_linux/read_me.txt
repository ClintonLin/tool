1. 功能说明：
    (a)一键式搜集java进程的问题定位信息，包括：Thread dump和Heap dump等。
    (b)监控java进程使用的cpu，当占用率过高时自动收集线程堆栈信息。
    由于jdk的文件体积比较大，本工具精简了jdk，只保留jdk中工具包(tools.jar)和连接java进程使用的类库(libattach.so)。

2. 使用方法：
将工具上传在服务器上的任意目录，并进行解压，但需保证运行java的用户有权限访问此目录。推荐放在/home目录，这个目录是满足权限要求的。
(1) 解压：    unzip -o java_tools_linux*.zip -d /home
(2) 收集信息：sh /home/java_tools_linux/jvm_info_collect.sh
(3) 监控进程：sh /home/java_tools_linux/jvm_cpu_monitor.sh.sh

3. 使用JDK工具常见问题：
常见错误1：
java.io.IOException: well-known file is not secure
    at sun.tools.attach.LinuxVirtualMachine.checkPermissions(Native Method)
    at sun.tools.attach.LinuxVirtualMachine.<init>(LinuxVirtualMachine.java:117)
    at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:63)
    at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:213)
    at sun.tools.jcmd.JCmd.executeCommandForPid(JCmd.java:140)
    at sun.tools.jcmd.JCmd.main(JCmd.java:129)

常见错误2：
com.sun.tools.attach.AttachNotSupportedException: Unable to open socket file: target process not responding or HotSpot VM not loaded
    at sun.tools.attach.LinuxVirtualMachine.<init>(LinuxVirtualMachine.java:106)
    at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:63)
    at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:213)
    at sun.tools.jcmd.JCmd.executeCommandForPid(JCmd.java:140)
    at sun.tools.jcmd.JCmd.main(JCmd.java:129)

常见错误3：
Exception in thread "main" java.lang.UnsatisfiedLinkError: no attach in java.library.path
    at java.lang.ClassLoader.loadLibrary(Unknown Source)
    at java.lang.Runtime.loadLibrary0(Unknown Source)
    at java.lang.System.loadLibrary(Unknown Source)
    at sun.tools.attach.LinuxVirtualMachine.<clinit>(LinuxVirtualMachine.java:336)
    at sun.tools.attach.LinuxAttachProvider.attachVirtualMachine(LinuxAttachProvider.java:63)
    at com.sun.tools.attach.VirtualMachine.attach(VirtualMachine.java:213)
    at sun.tools.jstack.JStack.runThreadDump(JStack.java:159)
    at sun.tools.jstack.JStack.main(JStack.java:112)

上述错误的可能的原因：
1) 当前操作系统的用户和要获取信息的Java进程的用户不同，导致权限不够，请合理修改工具目录的属主和权限，并且切换用户，切换然后操作。
2) 使用的jre版本过低。请使用export变量修改当前shell的jre运行环境信息，然后操作。
3）使用的jre和tools.jar版本不配套或缺失类库。请下载使用匹配的版本，更新相应的文件到工具的lib目录下，然后操作。
   查询JDK工具tools.jar对应的JDK版本号(需要反编译工具)：java_tools_linux\lib\tools.jar\com\sun\tools\javac\resources\version.class

4. 后续优化
(1)java_tools_linux\bin\jvm_info_collect_inner.sh中收集的结果根据类别输出到不同的文件。
(2)java_tools_linux\jvm_flight_recording.sh优化。

