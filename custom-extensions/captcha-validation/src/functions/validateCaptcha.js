const { app } = require('@azure/functions');
const axios = require('axios');

app.http('ValidateCaptcha', {
    methods: ['POST'],
    authLevel: 'function',
    handler: async (request, context) => {
        context.log('OnAttributeCollectionSubmit - CAPTCHA validation triggered.');

        try {
            const body = await request.json();

            // Extract CAPTCHA token from submitted attributes
            // Attribute name follows pattern: extension_<appId>_CaptchaToken
            const attributes = body?.data?.userSignUpInfo?.attributes || {};
            let captchaToken = null;

            for (const [key, value] of Object.entries(attributes)) {
                if (key.toLowerCase().endsWith('captchatoken')) {
                    captchaToken = value;
                    break;
                }
            }

            if (!captchaToken) {
                context.log('No CAPTCHA token found in request.');
                return {
                    status: 200,
                    jsonBody: createValidationError('CAPTCHA verification is required. Please complete the CAPTCHA challenge.')
                };
            }

            // Verify with Google reCAPTCHA
            const secretKey = process.env.RECAPTCHA_SECRET;
            if (!secretKey || secretKey === '<your-google-recaptcha-secret-key>') {
                context.log('RECAPTCHA_SECRET not configured.');
                return {
                    status: 200,
                    jsonBody: createValidationError('CAPTCHA service is not configured. Please contact support.')
                };
            }

            const verifyUrl = 'https://www.google.com/recaptcha/api/siteverify';
            const verifyResponse = await axios.post(verifyUrl, null, {
                params: {
                    secret: secretKey,
                    response: captchaToken
                }
            });

            const { success, score, action } = verifyResponse.data;
            context.log(`reCAPTCHA result: success=${success}, score=${score}, action=${action}`);

            if (!success) {
                context.log('CAPTCHA verification failed.', verifyResponse.data['error-codes']);
                return {
                    status: 200,
                    jsonBody: createValidationError('CAPTCHA verification failed. Please try again.')
                };
            }

            // For reCAPTCHA v3: check score threshold
            const scoreThreshold = parseFloat(process.env.RECAPTCHA_SCORE_THRESHOLD || '0.5');
            if (score !== undefined && score < scoreThreshold) {
                context.log(`CAPTCHA score ${score} below threshold ${scoreThreshold}.`);
                return {
                    status: 200,
                    jsonBody: createValidationError('Suspicious activity detected. Please try again or contact support.')
                };
            }

            // CAPTCHA valid — continue sign-up
            context.log('CAPTCHA validation passed.');
            return {
                status: 200,
                jsonBody: createContinueResponse()
            };

        } catch (error) {
            context.log(`Error during CAPTCHA validation: ${error.message}`);
            return {
                status: 200,
                jsonBody: createValidationError('An error occurred during verification. Please try again.')
            };
        }
    }
});

function createContinueResponse() {
    return {
        data: {
            "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
            actions: [
                {
                    "@odata.type": "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior"
                }
            ]
        }
    };
}

function createValidationError(message) {
    return {
        data: {
            "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
            actions: [
                {
                    "@odata.type": "microsoft.graph.attributeCollectionSubmit.showValidationError",
                    validationErrorMessage: message
                }
            ]
        }
    };
}
