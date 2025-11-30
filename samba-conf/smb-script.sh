user="wsUser1"
pass="testi123"

echo -e "$pass\n$pass" | smbpasswd -a -s $user
