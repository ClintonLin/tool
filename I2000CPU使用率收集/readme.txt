脚本有两种执行模式，一种是监控CPU，一种是监控某个进程
脚本可以配置执行时间（dultime=30）, 超时之后可以自动退出，默认30min，支持1-59的配置，范围之外会有bug
1. 监控CPU
	使用方法：./cpu.sh cpu
	可以生成cpu.info和top.info
	cpu.info中是时间和cpu的空闲量
	top.info中是时间和该时间cpu使用量高的前6个进程id
2. 监控进程
	使用方法：./cpu.sh 进程名 阈值
	可以生成 进程名.info 和 进程名.cpu.info
	进程名.cpu.info是时间和cpu的空闲量
	进程名.info中是时间和该时间cpu使用量最高的前6个线程id