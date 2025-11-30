# Set up Samba and UFW for NAS using Salt

This is a small project for Haaga-Helia University of Applied Sciences Configuration Management Systems course.
This project was made by [Mikko Niskala](https://github.com/Mikko-3) and [Niilo Myllynen](https://github.com/AntoineOkun).
Main idea of the project was to set up a Samba standalone server to share files over the local network and manage it with Salt.
Uncomplicated Firewall was included to make setting up firewall rules easier.

## Salt and UFW

- Configurations are made with Salt. UFW configurations are made to serve just the use of Samba.

## Samba


## References

- UFW [help.ubuntu.com](https://help.ubuntu.com/community/UFW)
- UFW & Samba [askubuntu.com](https://askubuntu.com/questions/36608/ufw-firewall-still-blocking-smb-despite-adding-rules)
- Salt project [SALT.STATES.CMD](https://docs.saltproject.io/en/latest/ref/states/all/salt.states.cmd.html#salt.states.cmd.run)
