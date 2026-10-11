# Set identification from install inputs
if [[ -n ${KOS_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$KOS_USER_NAME"
fi

if [[ -n ${KOS_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$KOS_USER_EMAIL"
fi
