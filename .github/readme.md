### Shadowsocks Manager

We strongly recommend that you use [WireGuard](https://github.com/complexorganizations/wireguard-manager) instead of Shadowsocks, but your best option is Shadowsocks if wireguard is blocked.

[Outline](https://getoutline.org/) is also suggested.

---
### Installation
Lets first use `curl` and save the file in `/usr/local/bin/`

```
curl https://raw.githubusercontent.com/complexorganizations/shadowsocks-manager/main/shadowsocks-manager.sh --create-dirs -o /usr/local/bin/shadowsocks-manager.sh
```
Then let's make the script user executable (Optional)
```
chmod +x /usr/local/bin/shadowsocks-manager.sh
```
It's finally time to execute the script
```
bash /usr/local/bin/shadowsocks-manager.sh
```

---
### Features
- Install Shadowsocks
- Uninstall Shadowsocks
- V2Ray Plugin

---
### Q&A

Why use shadowsocks?
- If your in a enviroment where wireguard is blocked than, shadowsocks is completely obfuscated, so stuff like DPI, wont work against shadowsocks. 

Why use V2Ray? 
- It obfuscates all proxy traffic, making it look like http, https traffic.

Is shadowsocks safe?
- Yes, all the code is completely open source.

How does shadowsocks traffic look like?
- It looks like normal http & https traffic.

---
### Author

* Name: Prajwal Koirala
* Website: [prajwalkoirala.com](https://www.prajwalkoirala.com)

---	
### Credits
Open Source Community

---
### License
Copyright © [Prajwal](https://github.com/prajwal-koirala)

This project is unlicensed.
