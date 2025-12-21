```bash
ls ~/.vscode/extensions | awk -F'-' '{print $1"."$2}'
```

```bash
code --list-extensions > vscode-extensions.txt
```
