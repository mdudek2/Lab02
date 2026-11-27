# Lab02 Questions

## Q1: State is a secret. Name three secrets that end up in the Terraform state file of this lab and explain why Terraform has to store them. List the protections the state bucket has, and say what the S3 lock object (use_lockfile) prevents?

Three secrets that end up in the Terraform state file are the admin password, the internal token, and the private keys for the internal CA. Terraform has to store this information because it is needed to deploy the necessary infrastructure. Without this information Terraform could not do it's job. The bucket has several protections in place such as server side encryption, protection from public access, and ownership controls. The S3 lock object (use_lockfile) is meant to protect against data corruption by preventing multiple terraform operations/processes from modyfiyng the same state file at the same time.

## Q2. What makes a subnet private? Point to the lines in network.tf that make public_a public and private_a private. What would happen to the private services if someone added a route to the internet gateway to the private route table? Why does the lab use a NAT instance, and what are the cost and security trade offs against a NAT gateway and against interface endpoints?

In AWS a private subnet is a subnet that does not have a direct route to an internet gatewway. Public subnets have direct routes to internet gateways. The lines of code in network.tf that decide whether a subnet is public or private begin on line 57. It is the resource block that assigns a subnet to the appropriate public/private route table. If someone were to add a route to the internet gateway to the private route table then the associated subnet would effectively become a public subnet because it would have a route to the internet gateway. The lab uses a NAT instance because it is the cheapest way of providing secure internet access to private resources.

In terms of cost a NAT instance is by far the cheapest because there is only an hourly fee plus the additional fee for a public facing IP address. There is no fee for the amount of traffic that passes through it. A managed NAT gateway would cost about 32 dollars a month multiplied by the amount of availability zones the system was in, and interface endpoints would cost around 7 dollars a month times the number of endpoints x the number of AZ's. Generally speaking a NAT instance is almost always going to be the cheapest, though the tradeoff is that it takes more work to configure and patch. Managed NAT gateways are the most cost efficient when there are many services and generally low traffic volume, while interface endpoints are the most cost efficient in high traffic volume systems with few services. In practice a real system would probably use a hybrid model to optimize cost efficiency.

In terms of security NAT instances are the most insecure because the user is responsible for patching the OS since it is bascially just an EC2 instance configured to perform routing. There is also a possibility of exposing ports to the internet on accident through a misconfiguration in a security group. A Managed NAT Gateway has the advantage of being managed by AWS, so the user does not have to patch the OS. A managed NAT gateway also does not support security groups and doesn't provide the ability to inspect traffic or enforce egress rules, this is done through AWS Network Firewall. Another issue is that traffic routed through a managed NAT gateway will use public endpoints even when it is meant to go to other internal AWS services. Interface endpoints are the most isolated and secure because they rely completely on AWS's internatl network and don't route traffic through the public internet. They also support security groups as well as resource level IAM policies.

## Q3. Two firewalls. Rule 105 in the public network ACL denies port 8443 after rule 100 allows your address, and rule 120 allows ephemeral ports. Explain why the deny is still needed, why the ACL needs reply rules and the security group does not, and give one thing each firewall can do that the other cannot?

The deny is still needed because rule 120 would accidentaly allow sending a reply to an attacker that is trying to access the admin console on port 8443 since 8443 is in the range of random ports in rule 120. Since rule 105 has higher precedence it overrides the allow in rule 120 and blocks any unauthorized access. The ACL needs reply rules because network ACL's are stateless and do not track connections. Because of this replies/egress traffic need to be explicitely allowed. Security groups are stateful, which means that they "track" connections and do not need any rules that explicity allow replies. Unlike security groups network ACL's can explicitely deny a specific address or range of addresses. Security groups cannot do this as they do not support deny rules. Security groups can reference other AWS resources directly without having to specify an IP address, while network ACL's cannot do this and each resources IP would have to be manually listed. Basically, NACL's allow for more specific rules at the IP level while security groups allow for more broad and easy to configure rules.

## Q4. One server, one role. Each microservice now has its own server and its own IAM role. What risk does this remove compared with several services sharing one role? Open svc-onboarding.json.tftpl and name the condition that stops the onboarding service from attaching AdministratorAccess, and one way a service that can create users might still escalate if the policy were careless?

Having one server per microservice and having individual IAM roles for the servers/microservices reduces the amount of permissions that an attacker can obtain if they were to compromise one of the servers. In the previous lab all microservices were installed on one server, so if that server were to be breached by an attacker then that attacker would be able to acquire all of the permissions from those microservices.

This is the condition that stops the onboarding service from attaching AdministratorAccess. It stops AdministratorAccess from attaching because the condition only allows attaching a specific policy. Any policy ARN that does not equal the specified pattern will be rejected.

```json

"Condition": {
    "ArnEquals": {
     "iam:PolicyARN": "arn:aws:iam::${account_id}:policy/nimbus/Nimbus-RequireMFA"
    }

```

If the policy were careless and did not use a condition to check what policy was being attached then then a service with the ability to create users could potentially be used to attach an extremely permissive policy such as AdministratorAccess. The service could also potentially be used to create console passwords for users that the attacker could use to login.

## Q5. Layers between services. A request to a private service must pass the network rules, mutual TLS, the internal token and the admin JWT. For each of the four, name one attack it stops and one it does not. Why do the certificates in this lab live only 72 hours?

Network rules stop communication from unauthorized IP addresses or internal subnets, but they cannot stop communication from an authorized source that has been compromised nor can they defend against spoofing. Mutual TLS is meant to stop man in the middle attacks by enforcing valid certificates for both parties, but it cannot stop an attacker that has acquired a valid certificate through a compromised service. The internal token stops requests that have not authenticated via the necessary credentials but a token can potentially be stolen or extracted by an attacker who is then able to bypass this guard. The admin JWT is designed to stop a regular user without admin privelages from performing an action that requires it, but it cannot defend against an attack from a compromised account. The certificates in this lab live for only 72 hours because it is generally better from a security standpoint to rotate certificates. Rotating certificates can minimize the damage that an attacker who steals a certificate can do because it's only valid for a short time.

## Q6 (explore). Where should secrets live? Compare SSM Parameter Store SecureString, AWS Secrets Manager and HashiCorp Vault for rotation, cost, auditing and access control. Then explain why secrets generated by Terraform are still exposed through the state file, and two ways to avoid that?

Secrets should generally always be stored in a secure environment like a secrets manager. They should never be hardcoded into an applications source code or into a deployment script because this exposes them to anyone who is able to access the source code. When it comes to rotation SSM Parameter Store doesn't natively support rotation, so this must be managed manually. In terms of cost it is the cheapest option as it does not cost anything in standard tier. In terms of auditing it can be audited through cloudtrail because it is an AWS service. From an access control standpoint SSM parameter store supports IAM policies for security.

AWS Secrets manager in comparison has built in support for rotation, In terms of cost it is not very expensive due to costing roughly around 40 cents per secret per month plus API costs. In terms of auditing it can be audited through AWS cloudtrail just like SSM Parameter Store because it is an AWS service. AWS Secrets Manager also supports IAM policies as well as resource based policies and KMS policies.

Hashicorp Vault costs absolutely nothing as it is open source, though it needs to be managed and configured by the user because it is not an AWS service. Vault also has native support for rotating secrets, though it is also the users responsibility to manage it because it is self hosted/deployed. Auditing also has to be handled by the user. Vault does not directly support Cloudtrail so the user/administrator has to use vaults built in auditing or implement another method to audit it. In terms of access controls Hashicorp Vault has it's own accounts and ACL policies, though it can be integrated with IAM.

Secrets that are generated through Terraform are exposed through the state file because Terraform needs to generate and store those secrets somewhere so that it can accurately compare states. It can't really hide the secrets because they need to be readable so that Terraform can perform its job. A few ways to avoid this are to make use of a secrets manager like Vault. With this configuration Terraform will not store secrets and it will instead query them from the secrets manager. Another way of avoiding exposing secrets through the state file is to use ephemeral values and write-only arguments. This will prevent Terraform from storing the secrets and it will instead send the secrets to the relevant API without keeping a local copy.

### Q7. Anatomy of a JWT. Using the token you decoded in H3, name the three parts of a JWT, say which of them is encrypted, and list the checks verify_jwt makes. For two of those checks, describe the attack or mistake it prevents?

The three parts of a JWT are the header, the payload, and the signature. The header contains information about the encoding and the algorithm that was used. The payload contains claims and statements about a user. For example the token that I decoded had a 'cognito:groups' key an 'iss' key, and a 'client_id' key. The signature contains the hash of the payload as well as cognitos cryptographic signature. Nothing in the JWT token is actually encrypted, but the signature was generated and signed cryptographically so the token cannot be forged even if it is read by an unauthorized third party.

#### verify_jwt function

```python

def verify_jwt(token, required_group=ADMIN_GROUP):
    """Return the claims of a valid ACCESS token or raise AuthError."""
    if not enabled():
        raise AuthError("cognito is not configured")
    if not token or token.count(".") != 2:
        raise AuthError("malformed token")
    try:
        key = _jwks_client().get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token, key, algorithms=["RS256"],               # a fixed list: "alg: none" and HS256 tricks are refused
            issuer=issuer(),                                # must come from OUR pool
            options={"require": ["exp", "iat", "iss", "sub"]})
    except (jwt.PyJWTError, BotoCoreError, OSError) as e:
        raise AuthError(f"token rejected: {e.__class__.__name__}")
    if claims.get("token_use") != "access":                 # an ID token must not be accepted as an access token
        raise AuthError("not an access token")
    if claims.get("client_id") != client_id():              # must have been issued to OUR app client
        raise AuthError("wrong app client")
    if required_group and required_group not in claims.get("cognito:groups", []):
        raise AuthError("not in the required group")
    return claims

```

The verify_jwt function makes the following checks:

- A check to see if the cognito is configured
- A JWT Structure and format check
- A key and cryptographic check
- An Issuer and claims check
- A network error check
- A token type check
- An App client check
- A group check

These checks are important from a security standpoint because they protect against forgery and privelage escalation. For example, the key and cryptographic check protects against forgery by retrieving cognitos public key and enforcing a specific algorithm. Without this check the attacker can execute a forgery attack by switching the algorithm that is used and/or signing the token themselves using a public key string. The group check prevents standard non admin users from accessing privelaged resources by making sure that the token matches a specific group. Without this check a regular user that is authenticated can simply use their own token because it would be considered valid.

### Q8 (explore). The limits of a bearer token. A JWT stays valid until it expires, even if the admin has left. Explain the revocation problem and how the 30 minute lifetime reduces it. Compare the USER_PASSWORD_AUTH flow used here with the OAuth 2.0 authorization code flow with PKCE and the Cognito hosted UI, and say which you would use in production and why?

The revocation problem is a situation where an administrator has left and is no longer a member of the company or department. However, they still have a valid token because it was cryptographically signed by cognito or by some other authentication service and there usually isn't any way to revoke the token on demand. The 30 minute lifetime in this lab defends against this problem because it limits the amount of time that the token remains active. 30 minutes is not a lot of time for an administrator to do damage because any authenticated session with an older token will not be able to stay authenticated for long.

The flow that was used in this lab involves entering credentials into the application and manually handling MFA verification directly in the applications code. With this setup the application directly handles usernames and passwords which means securing them is the application owners responsibility. On the other hand, AN OAuth 2.0 flow with PKCE and a Cognito hosted UI will handle the majority of the login process instead of relying on the application itself. The credentials as well as the MFA and they would not be managed directly by the app but would instead be managed by the Cognito hosted UI. The application would instead rely on a generated code that is protected by PKCE which protects codes from being intercepted. In this setup the entire login flow is externally managed and secured by a third party so it is much less maintenance for the administrator.

In a real production environment the OAuth 2.0 plus PKCE and Cognito hosted UI would be the preferred method because it is overall much more secure and it prevents the applicaiton from handling sensitive credentials directly. This protects against credentials being stolen as well as MFA from being exploited and is overall the recommended approach for a real system. Generally speaking most modern systems shouldn't really rely on manually handling the entire login flow because there are simply too many potential vulnerabilities and insecurities that are introduced with this.

### Q9. Plan, drift and immutable servers. Report how many resources terraform apply created (terraform state list) and what +, ~ and -/+ mean in a plan. Explain why changing one line of application code replaces the servers instead of updating them. After your hand edit in G7, how did Terraform find the change, and why would a rule that someone ADDS by hand not show in this plan?

After making the change manually terraform reported that it would need to make one change. After running the plan terraform added 0 new resources, changed 1 resource, and destroyed 0 resources. The + symbol means that terraform is going to create a resource, while the - symbol means that it is going to destroy it. The ~ symbol means that terraform is able to edit/update the resource without destroying it and creating it again. Terraform can also indicate -/+ or +/-. In these cases Terraform will destroy and then create a replacement for a resource, or create a replacement and then destroy the old resource. Terraform found the change because it was able to query the state of the AWS resources using the installed provider for AWS. It then compared it to the current plan and found that there was a mismatch. It was then able to fix the mismatch. A rule that someone adds by hand may not show up in the plan because terraform has no way of knowing about it's existence. Terraform can get information from the state file, it's configuration files, and also by querying resources. Something that was added by hand may not show up in any of these three places, so terraform wouldn't be able to detect it.

#### Terraform Output

```shell

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_vpc_security_group_ingress_rule.web_console will be updated in-place
  ~ resource "aws_vpc_security_group_ingress_rule" "web_console" {
      ~ cidr_ipv4              = "0.0.0.0/0" -> "MyIp/32"
      + description            = "Admin browser to the console (HTTPS, your address only)"
        id                     = "sgr-0332c90ae3a314fa3"
        # (7 unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_vpc_security_group_ingress_rule.web_console: Modifying... [id=sgr-0332c90ae3a314fa3]
aws_vpc_security_group_ingress_rule.web_console: Modifications complete after 0s [id=sgr-0332c90ae3a314fa3]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

Outputs:

admin_password = <sensitive>
admin_username = "admin"
alert_topic_arn = "arn:aws:sns:us-east-1:337820988322:lab02-security-alerts"
cognito_client_id = "1fbfk2lnb8g9i93aajrrn7341p"
cognito_user_pool_id = "us-east-2_ULaFpeD1M"
console_fingerprint_command = "aws ec2 get-console-output --instance-id i-0dde6133d5db5ba92 --latest --output text --region us-east-2 | grep 'BROWSER CERT'"
console_url = "https://3.12.155.193:8443"
data_bucket = "lab02-nimbus-337820988322"
free_tier_hours = 8
instance_ids = {
  "dashboard" = "i-02ef04dc77789e8eb"
  "nat" = "i-0fdf1bb258be4e361"
  "offboarding" = "i-070f72a8837d07cf1"
  "onboarding" = "i-00147e60df12c7b36"
  "web" = "i-0dde6133d5db5ba92"
}

```

### Q10 (explore). Prove it, then reflect. Record what you saw in H2: the three requests to the dashboard service (no client certificate, certificate but no token, certificate and token but no JWT) and which layer produced each result, and the IAM, S3 and metadata results from the web server. Then explain what IMDSv2 with a hop limit of 1 protects against, and what Session Manager records that SSH does not?

After running the tests in H2 I got the following results: The first check (no client certificate) returned a 000 code. This suggests that the request was blocked at the network/TLS level. The second test (certificate, no token) returned an http 401 code which means the request was unauthorized. This occured at the applications authentication layer. The third test (certificate and token no JWT) also returned an http 401 code like the previous test. Both requests in the fourth check returned an "AccessDenied". This suggests that the request was stopped at the API level/layer. The last check also returned a 401 due to not having a token. This was also stopped at the applications authentication layer.

IMDSv2 with a hop limit of 1 protects against server side request forgery. This is because it prevents an attacker from getting a token if the request was made outside of a network or a container. Session manager records more information than SSH does. For example, ssh might be able to log commands that were run on a server, but these commands would be logged on the server itself and an administrator would have to implement their own auditing and aggregation scripts to collect them. SSH on it's own is also completely incapable of recording anything that happens at the API level. For example, ssh can record that someone signed in to a server with admin credentials but it cannot determine the IAM user who logged in. AWS Session Manager is able to record not only a full session transcript but also exact timestamps as well as which IAM user initiated the connection. With Session Manager everything can be logged in Cloudtrail, Cloudwatch, and S3 easily. With SSH alone this isn't possible.

## Sources

<https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html>

<https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html>

<https://developer.hashicorp.com/vault/docs>

<https://oauth.net/2/>

<https://guptadeepak.com/ciam-compass/guides/token-lifetime-best-practices/>

<https://dev.to/afiqiqmal/aws-session-manager-vs-ssh-n3f>

<https://nhimg.org/faq/why-should-the-ec2-instance-metadata-response-hop-limit-be-set-to-1/>
