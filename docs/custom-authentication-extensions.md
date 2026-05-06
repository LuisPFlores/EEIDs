# Custom Authentication Extensions — OnAttributeCollectionSubmit

![Entra External ID](https://img.shields.io/badge/Microsoft%20Entra-Custom%20Extensions-0078D4?style=flat-square&logo=microsoft)
![Azure Functions](https://img.shields.io/badge/Azure-Functions%20v4-blue?style=flat-square&logo=azure-functions)

This module implements **OnAttributeCollectionSubmit** custom authentication extensions for Entra External ID, enabling server-side validation during user sign-up flows.

---

## 📋 Scenarios

| Scenario | Description | Runtime | Path |
|----------|-------------|---------|------|
| **Certificate Validation** | Validates uploaded `.cer` files (X.509) during sign-up | .NET 8 (isolated) | `custom-extensions/cert-validation/` |
| **CAPTCHA Validation** | Verifies Google reCAPTCHA tokens to prevent bot sign-ups | Node.js 20 | `custom-extensions/captcha-validation/` |

---

## 🏗️ Architecture

```
┌──────────────────────┐     ┌─────────────────────────────┐     ┌─────────────────────┐
│  User Sign-Up Page   │────▶│  Entra External ID          │────▶│  Azure Function     │
│  (Custom UI)         │     │  OnAttributeCollectionSubmit │     │  (Validation Logic) │
│                      │◀────│                             │◀────│                     │
└──────────────────────┘     └─────────────────────────────┘     └─────────────────────┘
         │                              │                                   │
         │  User submits form           │  Calls extension endpoint         │  Returns:
         │  with attributes             │  with user attributes             │  - Continue
         │                              │                                   │  - ValidationError
         │                              │                                   │  - BlockPage
```

### Response Contract

All functions return the Microsoft Graph `onAttributeCollectionSubmitResponseData` format:

```json
{
  "data": {
    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
    "actions": [
      {
        "@odata.type": "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior"
      }
    ]
  }
}
```

**Available actions:**

| Action | Purpose |
|--------|---------|
| `continueWithDefaultBehavior` | Allow sign-up to proceed |
| `showValidationError` | Show error message, let user retry |
| `modifyAttributeValues` | Override submitted attribute values |
| `showBlockPage` | Block sign-up entirely |

---

## 🔐 Scenario 1: Certificate (.cer) File Validation

### What It Does

- Receives a Base64-encoded `.cer` file from the sign-up form
- Parses it as an X.509 certificate
- Validates:
  - File is a valid certificate (not corrupt/fake)
  - Certificate has not expired
  - Certificate is currently valid (not future-dated)
- Returns validation error or allows sign-up to continue

### Prerequisites

- .NET 8 SDK
- Azure Functions Core Tools v4

### Local Development

```bash
cd custom-extensions/cert-validation

# Restore and build
dotnet restore
dotnet build

# Run locally
func start
```

**Test with curl:**

```bash
curl -X POST http://localhost:7071/api/ValidateCertUpload \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "userSignUpInfo": {
        "attributes": {
          "extension_abc123_CertificateData": "MIIDXTCCAkWgAwIBAgIJ..."
        }
      }
    }
  }'
```

### Custom Attribute Setup

1. In **Entra Admin Center** → **External Identities** → **User attributes**
2. Add custom attribute:
   - **Name**: `CertificateData`
   - **Data Type**: String
3. Add attribute to your sign-up user flow

### Custom UI Integration

Your sign-up page must encode the `.cer` file to Base64 before submitting:

```javascript
// Example: Read .cer file and encode to Base64
document.getElementById('cert-input').addEventListener('change', async (e) => {
    const file = e.target.files[0];

    // Validate extension client-side
    if (!file.name.toLowerCase().endsWith('.cer')) {
        alert('Please select a .cer file');
        return;
    }

    // Read as Base64
    const reader = new FileReader();
    reader.onload = () => {
        const base64 = reader.result.split(',')[1]; // Remove data:... prefix
        // Set the hidden attribute field value
        document.getElementById('extension_CertificateData').value = base64;
    };
    reader.readAsDataURL(file);
});
```

---

## 🤖 Scenario 2: CAPTCHA Validation (Google reCAPTCHA)

### What It Does

- Receives a reCAPTCHA token from the sign-up form
- Validates the token with Google's `siteverify` API
- For reCAPTCHA v3: enforces a configurable score threshold
- Returns validation error or allows sign-up to continue

### Prerequisites

- Node.js 20+
- Azure Functions Core Tools v4
- Google reCAPTCHA site key + secret key ([Get keys](https://www.google.com/recaptcha/admin))

### Local Development

```bash
cd custom-extensions/captcha-validation

# Install dependencies
npm install

# Configure local settings
# Edit local.settings.json → set RECAPTCHA_SECRET

# Run locally
func start
```

**Test with curl:**

```bash
curl -X POST http://localhost:7071/api/ValidateCaptcha \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "userSignUpInfo": {
        "attributes": {
          "extension_abc123_CaptchaToken": "03AGdBq24..."
        }
      }
    }
  }'
```

### Custom Attribute Setup

1. In **Entra Admin Center** → **External Identities** → **User attributes**
2. Add custom attribute:
   - **Name**: `CaptchaToken`
   - **Data Type**: String
3. Add attribute to your sign-up user flow (mark as **not visible** to user)

### Custom UI Integration

Add reCAPTCHA to your sign-up page:

```html
<!-- reCAPTCHA v2 (checkbox) -->
<script src="https://www.google.com/recaptcha/api.js" async defer></script>

<form id="signup-form">
    <!-- Your sign-up fields here -->

    <div class="g-recaptcha" data-sitekey="YOUR_SITE_KEY" data-callback="onCaptchaSuccess"></div>

    <input type="hidden" id="extension_CaptchaToken" name="extension_CaptchaToken" />
    <button type="submit">Sign Up</button>
</form>

<script>
function onCaptchaSuccess(token) {
    document.getElementById('extension_CaptchaToken').value = token;
}
</script>
```

**For reCAPTCHA v3 (invisible/score-based):**

```html
<script src="https://www.google.com/recaptcha/api.js?render=YOUR_SITE_KEY"></script>
<script>
document.getElementById('signup-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const token = await grecaptcha.execute('YOUR_SITE_KEY', { action: 'signup' });
    document.getElementById('extension_CaptchaToken').value = token;
    e.target.submit();
});
</script>
```

### Configuration

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `RECAPTCHA_SECRET` | Google reCAPTCHA secret key | *(required)* |
| `RECAPTCHA_SCORE_THRESHOLD` | Minimum score for v3 (0.0–1.0) | `0.5` |

---

## 🚀 Deployment

### Automated (Recommended)

```powershell
# Deploy both scenarios
.\scripts\CIAM\Deploy-CustomExtensions.ps1 `
    -ResourceGroupName "rg-eeid-extensions" `
    -Location "eastus" `
    -RecaptchaSecret "6Lc_your_secret_key"

# Deploy only certificate validation
.\scripts\CIAM\Deploy-CustomExtensions.ps1 `
    -ResourceGroupName "rg-eeid-extensions" `
    -Scenario CertValidation

# Deploy only CAPTCHA validation
.\scripts\CIAM\Deploy-CustomExtensions.ps1 `
    -ResourceGroupName "rg-eeid-extensions" `
    -Scenario CaptchaValidation `
    -RecaptchaSecret "6Lc_your_secret_key"
```

### Manual Deployment

#### Step 1: Create Azure Resources

```bash
# Resource group
az group create --name rg-eeid-extensions --location eastus

# Storage account
az storage account create \
    --name steeidextensions \
    --resource-group rg-eeid-extensions \
    --location eastus \
    --sku Standard_LRS
```

#### Step 2: Deploy Certificate Validation

```bash
cd custom-extensions/cert-validation

# Create Function App
az functionapp create \
    --resource-group rg-eeid-extensions \
    --consumption-plan-location eastus \
    --runtime dotnet-isolated \
    --runtime-version 8 \
    --functions-version 4 \
    --name func-eeid-cert \
    --storage-account steeidextensions

# Build and deploy
dotnet publish -c Release -o ./publish
cd publish
func azure functionapp publish func-eeid-cert --dotnet-isolated
```

#### Step 3: Deploy CAPTCHA Validation

```bash
cd custom-extensions/captcha-validation

# Create Function App
az functionapp create \
    --resource-group rg-eeid-extensions \
    --consumption-plan-location eastus \
    --runtime node \
    --runtime-version 20 \
    --functions-version 4 \
    --name func-eeid-captcha \
    --storage-account steeidextensions

# Set secrets
az functionapp config appsettings set \
    --name func-eeid-captcha \
    --resource-group rg-eeid-extensions \
    --settings "RECAPTCHA_SECRET=your-secret" "RECAPTCHA_SCORE_THRESHOLD=0.5"

# Deploy
npm install --production
func azure functionapp publish func-eeid-captcha
```

#### Step 4: Register Custom Authentication Extension in Entra

1. Go to **[Entra Admin Center](https://entra.microsoft.com)**
2. Navigate to **External Identities** → **Custom authentication extensions**
3. Click **+ Create a custom extension**
4. Configure:
   - **Event type**: OnAttributeCollectionSubmit
   - **Endpoint URL**: Your Azure Function URL (e.g., `https://func-eeid-cert.azurewebsites.net/api/ValidateCertUpload`)
   - **Authentication**: Configure an app registration with `CustomAuthenticationExtension.Receive.Payload` permission
5. Click **Create**

#### Step 5: Link to User Flow

1. Go to **User flows** → select your sign-up flow
2. Navigate to the **Attribute collection** page layout
3. Under **Custom extensions**, assign your extension
4. Select when to trigger: **On attribute collection submit**
5. Save the flow

---

## 🧪 Testing

### Test Locally

Both functions can be tested locally with `func start`:

```bash
# Terminal 1: Certificate validation
cd custom-extensions/cert-validation && func start --port 7071

# Terminal 2: CAPTCHA validation
cd custom-extensions/captcha-validation && func start --port 7072
```

### Generate Test Certificate

```powershell
# Create a self-signed test certificate (.cer)
$cert = New-SelfSignedCertificate `
    -Subject "CN=TestUser" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(1)

# Export to .cer (DER encoded)
Export-Certificate -Cert $cert -FilePath ".\test-cert.cer"

# Get Base64 for testing
$bytes = [System.IO.File]::ReadAllBytes(".\test-cert.cer")
$base64 = [Convert]::ToBase64String($bytes)
Write-Host $base64
```

### Test with Portal

After deployment and registration, use the **"Test"** button in the Custom Authentication Extension configuration page in Entra Admin Center.

---

## 🔒 Security Considerations

- **Never expose function keys** in client-side code
- Use **Managed Identity** for production deployments instead of function keys
- Configure **CORS** to allow only your custom UI domain
- Enable **Application Insights** for monitoring and alerting
- For CAPTCHA: keep `RECAPTCHA_SECRET` in Azure Key Vault for production
- For certificates: consider adding issuer/subject validation for higher security

---

## 📚 References

- [Custom authentication extensions overview](https://learn.microsoft.com/en-us/entra/identity-platform/custom-extension-overview)
- [OnAttributeCollectionSubmit event reference](https://learn.microsoft.com/en-us/entra/identity-platform/custom-extension-onattributecollectionsubmit-retrieve-return-data)
- [Configure custom extensions for attribute collection](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-define-custom-attributes)
- [Azure Functions deployment guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies)
- [Google reCAPTCHA documentation](https://developers.google.com/recaptcha/docs/verify)
