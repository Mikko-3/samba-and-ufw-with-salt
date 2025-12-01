# Set up Samba and UFW for NAS using Salt

This is a small project for Haaga-Helia University of Applied Sciences course Configuration Management Systems.
This project was made by [Mikko Niskala](https://github.com/Mikko-3) and [Niilo Myllynen](https://github.com/AntoineOkun).  
Main idea of the project was to set up a Samba standalone server to share files over the local network and manage it with Salt.
Uncomplicated Firewall (UFW) was included to make setting up firewall rules easier to protect the NAS from outside connections.

<img width="1024" height="461" alt="lopputulos" src="https://github.com/user-attachments/assets/af2f9b78-edc5-47fc-b734-472b5e44c70c" />

Click [here](https://github.com/Mikko-3/samba-and-ufw-with-salt/blob/main/raportti.md) for the full report (in Finnish).

## What it do?

This Salt configuration installs Samba and UFW to your Linux NAS and sets them up for you.
It creates the necessary UFW settings to allow Samba traffic through and activates the firewall.
Next it copies the Samba configuration file to the appropriate location with the necessary settings.
Finally, it creates a new user and group for Samba access, and adds the user to a new group and Samba.  
Check the [Modify settings](#modify-settings) section to see the defaults and how to change them.

## Installation instructions

**NOTE:** This project and the instructions were made using Debian, so if you are using some other opertating system, you might need to use different commands or file paths.
This project is unfortunately not compatible with Windows.

### Prerequisites

You need two computers (or virtual machines) on the same local network and [Salt](https://docs.saltproject.io/salt/install-guide/en/latest/index.html).  
Your NAS needs `salt-minion` installed, while your other computer needs the `salt-master` and `smbclient` installed.  
Some Salt installation instructions:  
[Salt in 10 minutes](https://docs.saltproject.io/en/latest/topics/tutorials/walkthrough.html)  
[Install Salt on Debian 13 Trixie](https://terokarvinen.com/install-salt-on-debian-13-trixie/)

### Installation

1. When you have Salt installed and setup, clone the repository with your preferred method or download as .zip and extract.
2. Copy the files to `/srv/salt/`. (You can omit the readme.md, licence and raportti.md files.)
3. Run `sudo salt '*' state.apply` command.
4. Everything should be installed and running.
5. You are now ready to connect to the share using `smbclient`! (`smbclient -U wsUser1 //Your-NAS-IP-address/nas`)
6. Run the Salt command again every now and then to keep Samba and UFW up-to-date.

## Modify settings

Here's some things you might want/need to modify to make the configuration work better for you.  
**NOTE:** Salt is very picky when it comes to the syntax of the .sls files, so don't remove or add any blank characters or anything else.
If Salt gives you errors or doesn't do what it is supposed to and you modified the files, you might have accidentally changed the indentations.
Check here how to fix it: [What is YAML and How To Use It](https://docs.saltproject.io/en/latest/topics/yaml/index.html)

### Share path and name

The name of the share is `nas` and it's located in `/srv/samba/`.
If you want to change either, you need to modify the `smb.conf` file AND the `init.sls` file, both located in the `samba-conf` folder.  
**smb.conf:** change the `path =` variable to the path you want.
If you want to change the name of the share only, change the `nas` part of `/srv/samba/nas/`.  
**init.sls:** Navigate to `/srv/samba/nas` and change this to be the same as you put in `smb.conf`.

### Username and password

The name of the user created is `wsUser1` and the password is `testi123`.
These are used to connect to the Samba share. The password is definitely not good or secure, so it's recommended to change it to something else.  
If you want to change either, head on to `init.sls` in `samba-conf`.
Navigate to `wsUser1` and change it to be what you want the new username to be.
Under that, there is the `password` variable, where you can change it to be your desired password.  
If you changed the username, you need to modify a couple of other parts as well.
Navigate to `nasUsers` and change the `addusers:` to be the new username.
Last, navigate to `smbpasswd` and change the `oncahnges` option with the same name as the user.
This option makes the script idempotent, so it doesn't execute if there aren't any changes.  
If you changed the username or the password or both, you also need to edit the `smb-script.sh` file in `samba-conf`.
Change the `user=` and `pass=` to the username and password respectively.

### Apply changes

Once you've saved the changes, you can run the `sudo salt '*' state.apply` command. This updates the configurations on the minion.  
**NOTE:** if you have already ran the command at least once before the modifications, Salt won't remove the default user and folder from your NAS.
You need to do this by hand, or create a new Salt state to do that.


## Question: Why Salt? Why not just install Samba on my own?

Sure, that works too, but management can be a bother.
You need to manually login to your NAS and update the software and such.
Salt automates this tedious process, as long as you are willing to do a little bit of work upfront.  
This Salt project is idempotent, meaning it will only apply changes, if the system is not in the state it's supposed to be.
So running the Salt command more than once doesn't re-install your Samba and UFW and their settings, but updates them and their respective settings, if needed.

## References
Salt project: https://saltproject.io/  
Samba: https://www.samba.org/  
UFW: https://wiki.debian.org/Uncomplicated%20Firewall%20%28ufw%29
Salt installation guides:  
Karvinen, T. 2025. Install Salt on Debian 13 Trixie. https://terokarvinen.com/install-salt-on-debian-13-trixie/  
VMware. 2025. Salt In 10 Minutes. https://docs.saltproject.io/en/latest/topics/tutorials/walkthrough.html  
YAML: What is YAML and How To Use It. https://docs.saltproject.io/en/latest/topics/yaml/index.html
