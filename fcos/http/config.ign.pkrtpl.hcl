{
  "ignition": {
    "version": "3.4.0"
  },
  "passwd": {
    "users": [
      {
        "name": "core",
        "groups": [
          "sudo",
          "docker"
        ],
        "shell": "/bin/bash",
        "sshAuthorizedKeys": [
          "${SSH_KEY}"
        ]
      }
    ]
  },
  "systemd": {
    "units": [
      {
        "name": "cloud-init.service",
        "enabled": true
      },
      {
        "name": "cloud-config.service", 
        "enabled": true
      },
      {
        "name": "cloud-final.service",
        "enabled": true
      },
      {
        "name": "maas-machine-setup.service",
        "enabled": true
      },
      {
        "name": "packer-shutdown.service",
        "enabled": true,
        "contents": "[Unit]\nDescription=Auto-shutdown for Packer build\nAfter=multi-user.target\n\n[Service]\nType=oneshot\nExecStartPre=/bin/sleep 180\nExecStart=/usr/bin/systemctl poweroff\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n"
      }
    ]
  },
  "storage": {
    "files": [
      {
        "path": "/etc/cloud/cloud.cfg.d/10_maas.cfg",
        "contents": {
          "inline": "datasource_list: [MAAS]\ndatasource:\n  MAAS:\n    timeout: 50\n    max_wait: 120\n    consumer_key: null\n    token_key: null\n    token_secret: null\n    metadata_url: null\n"
        },
        "mode": 420
      },
      {
        "path": "/etc/cloud/cloud.cfg.d/90_disable_network_config.cfg",
        "contents": {
          "inline": "network: {config: disabled}\n"
        },
        "mode": 420
      },
      {
        "path": "/etc/cloud/cloud.cfg.d/20_maas_logging.cfg",
        "contents": {
          "inline": "output:\n  all: '| tee -a /var/log/cloud-init-output.log'\n"
        },
        "mode": 420
      },
      {
        "path": "/etc/systemd/system/maas-machine-setup.service",
        "contents": {
          "inline": "[Unit]\nDescription=MAAS machine setup\nAfter=cloud-final.service\nWants=cloud-final.service\n\n[Service]\nType=oneshot\nExecStart=/bin/true\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n"
        },
        "mode": 420
      }
    ]
  }
}