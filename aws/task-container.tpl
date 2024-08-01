{
	"name": "${xtcross-container-name}",
	"image": "${xtcross-container-image}",
	"cpu": ${xtcross-container-cpu},
	"memory": ${xtcross-container-memory},
	"essential":  ${xtcross-container-essential},
	"portMappings": ${xtcross-container-portmap},
	"environment" : ${xtcross-container-environment},
	"logConfiguration": {"logDriver": "awsfirelens"},
	"command": ${xtcross-container-command},
	"entryPoint": ${xtcross-container-entrypoint},
	"dependsOn": ${xtcross-container-dependency},
	"healthCheck": ${xtcross-container-healthcheck},
	"firelensConfiguration": ${xtcross-container-firelensconfiguration},
	"mountPoints": ${xtcross-container-mountpoint}
}