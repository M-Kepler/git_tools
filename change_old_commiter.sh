echo "修改里面的 OLD_NAME、CORRECT_NAME、CORRENT_EMAIL"
#!/bin/sh

git filter-branch --env-filter '

OLD_NAME="$1"
CORRECT_NAME="$2"
CORRECT_EMAIL="$3"

if [ "$GIT_COMMITTER_NAME" = "$OLD_NAME" ]
then
    export  GIT_COMMITTER_NAME="$CORRECT_NAME"
    export  GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
    export  GIT_AUTHOR_NAME="$CORRECT_NAME"
    export  GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi

if [ "$GIT_AUTHOR_NAME" = "$OLD_NAME" ]
then
    export  GIT_COMMITTER_NAME="$CORRECT_NAME"
    export  GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
    export  GIT_AUTHOR_NAME="$CORRECT_NAME"
    export  GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi

' --tag-name-filter cat -- --branches --tags

