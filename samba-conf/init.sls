/etc/samba/smb.conf:
  file.managed:
    - source: salt://samba-conf/smb.conf

wsUser1:
  user.present:
    - createhome: false
    - shell: /sbin/nologin
    - password: testi123

nasUsers:
  group.present:
    - addusers:
      - wsUser1

/srv/samba/nas:
  file.directory:
    - makedirs: true
    - group: nasUsers
    - mode: 2770
    - recurse:
      - group

smbpasswd:
  cmd.script:
    - name: salt://samba-conf/smb-script.sh
    - onchanges:
      - wsUser1

smbd:
  service.running:
    - onchanges:
      - file: /etc/samba/smb.conf
