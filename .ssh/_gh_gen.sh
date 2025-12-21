# Just paste the key G
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/github -C "github-$(hostname)"
eval "$(ssh-agent -s)" >/dev/null
ssh-add -q ~/.ssh/github
copy < ~/.ssh/github.pub

