using System.Net;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace CertValidation;

public class ValidateCertUpload
{
    private readonly ILogger _logger;

    public ValidateCertUpload(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<ValidateCertUpload>();
    }

    [Function("ValidateCertUpload")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
    {
        _logger.LogInformation("OnAttributeCollectionSubmit - Certificate validation triggered.");

        var requestBody = await req.ReadAsStringAsync();
        var response = req.CreateResponse();
        response.Headers.Add("Content-Type", "application/json");

        try
        {
            using var doc = JsonDocument.Parse(requestBody!);
            var root = doc.RootElement;

            // Navigate: data -> userSignUpInfo -> attributes -> extension_<appId>_CertificateData
            string? certBase64 = null;

            if (root.TryGetProperty("data", out var data) &&
                data.TryGetProperty("userSignUpInfo", out var userInfo) &&
                userInfo.TryGetProperty("attributes", out var attributes))
            {
                // Look for any attribute ending with "CertificateData"
                foreach (var attr in attributes.EnumerateObject())
                {
                    if (attr.Name.EndsWith("CertificateData", StringComparison.OrdinalIgnoreCase))
                    {
                        certBase64 = attr.Value.GetString();
                        break;
                    }
                }
            }

            if (string.IsNullOrWhiteSpace(certBase64))
            {
                _logger.LogWarning("No certificate data found in request attributes.");
                await WriteResponse(response, CreateValidationError("Certificate file is required. Please upload a .cer file."));
                return response;
            }

            // Validate the certificate
            var certBytes = Convert.FromBase64String(certBase64);
            var cert = new X509Certificate2(certBytes);

            _logger.LogInformation("Certificate parsed: Subject={Subject}, Issuer={Issuer}, NotAfter={NotAfter}",
                cert.Subject, cert.Issuer, cert.NotAfter);

            // Check if certificate has expired
            if (cert.NotAfter < DateTime.UtcNow)
            {
                _logger.LogWarning("Certificate has expired on {NotAfter}.", cert.NotAfter);
                await WriteResponse(response, CreateValidationError(
                    $"Certificate expired on {cert.NotAfter:yyyy-MM-dd}. Please upload a valid, non-expired certificate."));
                return response;
            }

            // Check if certificate is not yet valid
            if (cert.NotBefore > DateTime.UtcNow)
            {
                _logger.LogWarning("Certificate is not yet valid until {NotBefore}.", cert.NotBefore);
                await WriteResponse(response, CreateValidationError(
                    $"Certificate is not valid until {cert.NotBefore:yyyy-MM-dd}. Please upload a currently valid certificate."));
                return response;
            }

            // Certificate is valid — continue sign-up
            _logger.LogInformation("Certificate validation passed for Subject={Subject}.", cert.Subject);
            await WriteResponse(response, CreateContinueResponse());
            return response;
        }
        catch (FormatException)
        {
            _logger.LogError("Certificate data is not valid Base64.");
            await WriteResponse(response, CreateValidationError(
                "Invalid certificate format. Please upload a valid .cer file encoded in Base64."));
            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during certificate validation.");
            await WriteResponse(response, CreateValidationError(
                "Unable to validate the certificate. Please ensure you uploaded a valid .cer file."));
            return response;
        }
    }

    private static async Task WriteResponse(HttpResponseData response, object body)
    {
        var json = JsonSerializer.Serialize(body, new JsonSerializerOptions
        {
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        });
        response.StatusCode = HttpStatusCode.OK;
        await response.WriteStringAsync(json);
    }

    private static object CreateContinueResponse() => new ResponseEnvelope
    {
        Data = new ResponseData
        {
            ODataType = "microsoft.graph.onAttributeCollectionSubmitResponseData",
            Actions = new[]
            {
                new ResponseAction
                {
                    ODataType = "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior"
                }
            }
        }
    };

    private static object CreateValidationError(string message) => new ResponseEnvelope
    {
        Data = new ResponseData
        {
            ODataType = "microsoft.graph.onAttributeCollectionSubmitResponseData",
            Actions = new[]
            {
                new ResponseAction
                {
                    ODataType = "microsoft.graph.attributeCollectionSubmit.showValidationError",
                    ValidationErrorMessage = message
                }
            }
        }
    };
}

// Response models with proper @odata.type serialization
public class ResponseEnvelope
{
    [JsonPropertyName("data")]
    public ResponseData Data { get; set; } = new();
}

public class ResponseData
{
    [JsonPropertyName("@odata.type")]
    public string ODataType { get; set; } = string.Empty;

    [JsonPropertyName("actions")]
    public ResponseAction[] Actions { get; set; } = Array.Empty<ResponseAction>();
}

public class ResponseAction
{
    [JsonPropertyName("@odata.type")]
    public string ODataType { get; set; } = string.Empty;

    [JsonPropertyName("validationErrorMessage")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? ValidationErrorMessage { get; set; }
}
