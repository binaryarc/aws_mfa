# AWS MFA

> 이 글은 GitHub MCP 서버로 작성된 글 입니다.

## 🔎 개요

이 레포지토리는 AWS CLI를 사용할 때 MFA(Multi-Factor Authentication) 인증을 간편하게 처리할 수 있도록 도와주는 스크립트를 제공합니다. AWS 계정의 보안을 강화하면서도 CLI 작업을 효율적으로 수행할 수 있게 해줍니다.

## 📂 레포지토리 구조

레포지토리는 다음과 같은 파일들로 구성되어 있습니다:

- **README.md**: 사용법 및 설명 문서
- **aws_auth_mfa.sh**: AWS MFA 인증을 처리하는 메인 스크립트
- **requirement.sh**: 필요한 의존성 설치를 위한 스크립트

## 🔧 주요 기능

### aws_auth_mfa.sh

이 스크립트의 주요 기능은 다음과 같습니다:

1. AWS 프로필 정보와 MFA 토큰을 입력받음
2. AWS STS(Security Token Service)를 통해 임시 자격 증명을 발급
3. 발급받은 임시 자격 증명을 새로운 프로필('mfa')에 저장
4. 세션 토큰은 기본적으로 12시간(43200초) 동안 유효함

```bash
# 스크립트 실행 예시
./aws_auth_mfa.sh your_profile 123456
```

### requirement.sh

이 스크립트는 필요한 의존성을 설치합니다:

1. AWS Linux나 Ubuntu 환경에서 jq(JSON 처리 도구) 설치
2. AWS CLI 설정 방법 안내

## 💡 개선 제안

현재 코드를 분석한 후 다음과 같은 개선 사항을 제안합니다:

### 1. 기능 확장

- **프로필 이름 커스터마이징**: MFA 프로필 이름을 매개변수로 받아 사용자가 지정할 수 있도록 함
- **세션 지속 시간 커스터마이징**: 세션 지속 시간도 매개변수로 받아 사용자가 조정할 수 있도록 함
- **다중 프로필 지원**: 여러 AWS 계정/프로필을 동시에 관리할 수 있는 기능 추가

### 2. 사용자 경험 개선

- **대화형 모드 추가**: 매개변수 없이 실행했을 때 대화형으로 정보를 입력받을 수 있게 함
- **오류 메시지 개선**: 더 명확하고 해결책을 제시하는 오류 메시지 제공
- **도움말 기능 추가**: --help 옵션을 추가하여 사용법을 쉽게 확인할 수 있게 함

### 3. 코드 품질 향상

- **입력값 검증 강화**: MFA 토큰 형식 검증 등 사용자 입력 검증 로직 추가
- **AWS CLI 버전 검증**: 필요한 AWS CLI 최소 버전 확인 로직 추가
- **로깅 기능 추가**: 디버깅을 위한 로깅 추가 (옵션으로 활성화 가능)
- **에러 처리 방식 개선**: 다양한 에러 상황에 대한 더 세밀한 처리

### 4. 문서화 개선

- **설치 및 사용법 가이드 확장**: 더 자세한 설정 가이드와 사용 예시 제공
- **AWS MFA 설정 가이드 추가**: AWS MFA 장치 설정 방법 안내
- **트러블슈팅 섹션 추가**: 일반적인 문제와 해결책 문서화

## 📝 구현 예시: 개선된 aws_auth_mfa.sh

아래 코드는 위에서 제안한 개선 사항 중 일부를 구현한 예시입니다:

```bash
#!/bin/bash
# Improved AWS MFA Authentication Script

# Default values
DEFAULT_MFA_PROFILE="mfa"
DEFAULT_SESSION_DURATION=43200 # 12 hours

# Help function
show_help() {
  echo "Usage: $0 [OPTIONS] AWS_PROFILE MFA_TOKEN"
  echo
  echo "Options:"
  echo "  -h, --help                 Show this help message"
  echo "  -p, --profile NAME         Set custom MFA profile name (default: $DEFAULT_MFA_PROFILE)"
  echo "  -d, --duration SECONDS     Set custom session duration in seconds (default: $DEFAULT_SESSION_DURATION)"
  echo "  -v, --verbose              Enable verbose mode"
  echo
  echo "Example:"
  echo "  $0 myprofile 123456"
  echo "  $0 --profile mymfa --duration 3600 myprofile 123456"
  exit 0
}

# Parse command-line options
VERBOSE=false
MFA_PROFILE=$DEFAULT_MFA_PROFILE
SESSION_DURATION=$DEFAULT_SESSION_DURATION

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -p|--profile)
      MFA_PROFILE="$2"
      shift 2
      ;;
    -d|--duration)
      SESSION_DURATION="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Check required arguments
if [ $# -lt 2 ]; then
  echo "Error: Missing required arguments"
  echo "Try '$0 --help' for more information"
  exit 1
fi

AWS_PROFILE="$1"
MFA_TOKEN="$2"

# Validate MFA token
if ! [[ $MFA_TOKEN =~ ^[0-9]{6}$ ]]; then
  echo "Error: MFA token must be a 6-digit number"
  exit 1
fi

# Main function
create_mfa_profile() {
  local aws_profile="$1"
  local mfa_token="$2"
  local mfa_profile="$3"
  local session_duration="$4"
  
  # Get MFA serial number
  local mfa_serial_number=$(aws configure --profile "$aws_profile" get aws_arn_mfa)
  if [ -z "$mfa_serial_number" ]; then
    echo "Error: MFA serial number is not set for profile '$aws_profile'"
    echo "Please set it by running: aws configure --profile \"$aws_profile\" set aws_arn_mfa <your-mfa-arn>"
    exit 1
  fi
  
  [ "$VERBOSE" = true ] && echo "Getting temporary credentials using MFA device: $mfa_serial_number"
  
  # Get temporary credentials
  local tmp_credentials
  tmp_credentials=$(aws sts get-session-token \
    --profile "$aws_profile" \
    --serial-number "$mfa_serial_number" \
    --token-code "$mfa_token" \
    --duration-seconds "$session_duration")
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to get temporary credentials"
    echo "Please check your AWS profile, MFA device, and token"
    exit 2
  fi
  
  # Extract credentials
  local aws_access_key_id=$(echo "$tmp_credentials" | jq -r .Credentials.AccessKeyId)
  local aws_secret_access_key=$(echo "$tmp_credentials" | jq -r .Credentials.SecretAccessKey)
  local aws_session_token=$(echo "$tmp_credentials" | jq -r .Credentials.SessionToken)
  local expiration=$(echo "$tmp_credentials" | jq -r .Credentials.Expiration)
  
  # Configure profile with temporary credentials
  aws configure --profile "$mfa_profile" set aws_access_key_id "$aws_access_key_id"
  aws configure --profile "$mfa_profile" set aws_secret_access_key "$aws_secret_access_key"
  aws configure --profile "$mfa_profile" set aws_session_token "$aws_session_token"
  
  # Copy region and output format settings from original profile
  local region=$(aws configure --profile "$aws_profile" get region)
  local output=$(aws configure --profile "$aws_profile" get output)
  
  if [ -n "$region" ]; then
    aws configure --profile "$mfa_profile" set region "$region"
  fi
  
  if [ -n "$output" ]; then
    aws configure --profile "$mfa_profile" set output "$output"
  fi
  
  echo "Success! MFA credentials configured for profile: $mfa_profile"
  echo "Credentials will expire at: $expiration"
  echo
  echo "To use these credentials, add --profile $mfa_profile to your AWS CLI commands:"
  echo "Example: aws --profile $mfa_profile s3 ls"
}

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed"
  echo "Please install it using your package manager"
  echo "For example: sudo apt install jq or sudo yum install jq"
  exit 3
fi

if ! command -v aws &> /dev/null; then
  echo "Error: AWS CLI is not installed"
  echo "Please install it following the instructions at:"
  echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 3
fi

# Run main function
create_mfa_profile "$AWS_PROFILE" "$MFA_TOKEN" "$MFA_PROFILE" "$SESSION_DURATION"
```

## 🚀 결론

이 도구는 AWS CLI에서 MFA 인증을 쉽게 처리할 수 있는 유용한 스크립트를 제공합니다. 기본적인 기능을 충실히 수행하고 있지만, 사용자 경험과 코드 품질 측면에서 개선할 수 있는 여지가 있습니다.

위에서 제안한 개선 사항들을 적용하면 더 유연하고 사용하기 쉬운 도구로 발전시킬 수 있을 것입니다. 특히 대화형 모드 추가와 커스터마이징 기능은 다양한 사용자의 필요에 맞게 도구를 활용할 수 있게 해줄 것입니다.

## 요구 사항

- AWS CLI v2
- jq (JSON 파서)
- AWS 계정 및 MFA 장치 설정
