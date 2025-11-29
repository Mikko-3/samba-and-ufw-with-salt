user="wsUser1"
pass="olen)Omena4"

echo -e "$pass\n$pass" | smbpasswd -a -s $user
