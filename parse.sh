
throw () {
  echo "$*" >&2
  exit 1
}

tokenize () {
  local ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
  local CHAR='[^[:cntrl:]"\\]'
  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'
  egrep -ao "$STRING|$NUMBER|$KEYWORD|$SPACE|." --color=never |
    egrep -v "^$SPACE$"  # eat whitespace
}

parse_array () {
  local index=0
  local ary=''
  read -r token
  while true;
  do
    case "$token" in
      ']') break ;;
    esac
    parse_value "$1" "$index"
    let index=$index+1
    ary="$ary""$value" 
    read -r token
    case "$token" in
      ']') break ;;
      ',') ary="$ary", ;;
      *) throw "EXPECTED ] or , GOT ${token:-EOF}" ;;
    esac
    read -r token
  done
  value=`printf '[%s]' $ary`
}

parse_object () {
  local key
  local obj=''
  read -r token
  while :
  do
    case "$token" in
      '}') break ;;
      '"'*'"') key=$token ;;
      *) throw "EXPECTED STRING, GOT ${token:-EOF}" ;;
    esac
    read -r token
    case "$token" in
      ':') ;;
      *) throw "EXPECTED COLON, GOT ${token:-EOF}" ;;
    esac
    read -r token
    parse_value "$1" "$key"
    obj="$obj$key:$value"        
    read -r token
    case "$token" in
      '}') break;;
      ',') obj="$obj,"; read -r token ;;
      *) throw "EXPECTED , or }, but got ${token:-EOF}" ;;
    esac
  done
  value=`printf '{%s}' "$obj"`
}

parse_value () {
  local jpath="${1:+$1,}$2"
  case "$token" in
    '{') parse_object "$jpath" ;;
    '[') parse_array  "$jpath" ;;
    # At this point, the only valid single-character tokens are digits.
    ''|[^0-9]) throw "EXPECTED value, GOT ${token:-EOF}" ;;
    *) value=$token ;;
  esac
  printf "[%s]\t%s\n" "$jpath" "$value"
}

parse () {
  read -r token
  parse_value
  read -r token
  case "$token" in
    '') ;;
    *) throw "EXPECTED EOF, GOT $token" ;;
  esac
}
