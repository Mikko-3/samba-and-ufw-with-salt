/etc/samba/smb.conf:
  file.managed:
    - source: salt://samba-conf/smb.conf

wsUser1:
  user.present:
    - createhome: false
    - password: olen)Omena4

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
