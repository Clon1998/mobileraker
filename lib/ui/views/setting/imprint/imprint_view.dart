import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ImprintView extends StatelessWidget {
  const ImprintView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('Legal Content'),
        ),
        body: SingleChildScrollView(
          child: RichText(
            text: TextSpan(text: '', children: [
              TextSpan(
                style: Theme.of(context).textTheme.displaySmall,
                text: 'Imprint\n'
              ),
              TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  text:
                      'The following information (Impressum) is required under German law.\n'),
              TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  text: 'Patrick Schmidt\n'
                      'Thüringer Str. 12\n'
                      '64367 Mühltal\n'
                      'Contact: ps_schmidt@yahoo.com\n\n'),
              TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  text:
                      'Online Dispute Resolution website of the EU Commission\n',
                  children: [
                    TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        text:
                            'In order for consumers and traders to resolve a dispute out-of-court, the European Commission developed the Online Dispute Resolution Website: www.ec.europa.eu/consumers/odr\n\n')
                  ]),
              TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  text: 'Legal disclaimer\n',
                  children: [
                    TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        text:
                            'The contents of the app\'s pages were prepared with utmost care. Nonetheless, we cannot assume liability for the timeless accuracy and completeness of the information.\n'
                            'Our app contains links to external websites. As the contents of these third-party websites are beyond our control, we cannot accept liability for them. Responsibility for the contents of the linked pages is always held by the provider or operator of the pages.\n\n')
                  ]),
              TextSpan(
                  style: Theme.of(context).textTheme.displaySmall,
                  text:
                      'PRIVACY NOTICE\n',
                  children: [
                    TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        text:
                            'Last updated March 02, 2022\n'
                            '\n'
                            '\n'
                            '\n'
                            'This privacy notice for Mobileraker ("Company," "we," "us," or "our"), describes how and why we might collect, store, use, and/or share ("process") your information when you use our services ("Services"), such as when you:\n'
                            'Download and use our application(s), such as our mobile application — Mobileraker, or any other application of ours that links to this privacy notice\n'
                            'Engage with us in other related ways ― including any sales, marketing, or events\n'
                            'Questions or concerns? Reading this privacy notice will help you understand your privacy rights and choices. If you do not agree with our policies and practices, please do not use our Services. If you still have any questions or concerns, please contact us at ps_schmidt@yahoo.com.\n'
                            '\n'
                            '\n'
                            'SUMMARY OF KEY POINTS\n'
                            '\n'
                            'This summary provides key points from our privacy notice, but you can find out more details about any of these topics by clicking the link following each key point or by using our table of contents below to find the section you are looking for. You can also click here to go directly to our table of contents.\n'
                            '\n'
                            'What personal information do we process? When you visit, use, or navigate our Services, we may process personal information depending on how you interact with Mobileraker and the Services, the choices you make, and the products and features you use. Click here to learn more.\n'
                            '\n'
                            'Do we process any sensitive personal information? We do not process sensitive personal information.\n'
                            '\n'
                            'Do you receive any information from third parties? We do not receive any information from third parties.\n'
                            '\n'
                            'How do you process my information? We process your information to provide, improve, and administer our Services, communicate with you, for security and fraud prevention, and to comply with law. We may also process your information for other purposes with your consent. We process your information only when we have a valid legal reason to do so. Click here to learn more.\n'
                            '\n'
                            'In what situations and with which types of parties do we share personal information? We may share information in specific situations and with specific categories of third parties. Click here to learn more.\n'
                            '\n'
                            'How do we keep your information safe? We have organizational and technical processes and procedures in place to protect your personal information. However, no electronic transmission over the internet or information storage technology can be guaranteed to be 100% secure, so we cannot promise or guarantee that hackers, cybercriminals, or other unauthorized third parties will not be able to defeat our security and improperly collect, access, steal, or modify your information. Click here to learn more.\n'
                            '\n'
                            'What are your rights? Depending on where you are located geographically, the applicable privacy law may mean you have certain rights regarding your personal information. Click here to learn more.\n'
                            '\n'
                            'How do I exercise my rights? The easiest way to exercise your rights is by filling out our data subject request form available here, or by contacting us. We will consider and act upon any request in accordance with applicable data protection laws.\n'
                            '\n'
                            'Want to learn more about what Mobileraker does with any information we collect? Click here to review the notice in full.\n'
                            '\n'
                            '\n'
                            'TABLE OF CONTENTS\n'
                            '\n'
                            '1. WHAT INFORMATION DO WE COLLECT?\n'
                            '2. HOW DO WE PROCESS YOUR INFORMATION?\n'
                            '3. WHAT LEGAL BASES DO WE RELY ON TO PROCESS YOUR PERSONAL INFORMATION?\n'
                            '4. WHEN AND WITH WHOM DO WE SHARE YOUR PERSONAL INFORMATION?\n'
                            '5. HOW LONG DO WE KEEP YOUR INFORMATION?\n'
                            '6. HOW DO WE KEEP YOUR INFORMATION SAFE?\n'
                            '7. DO WE COLLECT INFORMATION FROM MINORS?\n'
                            '8. WHAT ARE YOUR PRIVACY RIGHTS?\n'
                            '9. CONTROLS FOR DO-NOT-TRACK FEATURES\n'
                            '10. DO CALIFORNIA RESIDENTS HAVE SPECIFIC PRIVACY RIGHTS?\n'
                            '11. DO WE MAKE UPDATES TO THIS NOTICE?\n'
                            '12. HOW CAN YOU CONTACT US ABOUT THIS NOTICE?\n'
                            '13. HOW CAN YOU REVIEW, UPDATE, OR DELETE THE DATA WE COLLECT FROM YOU?\n'
                            '\n'
                            '1. WHAT INFORMATION DO WE COLLECT?\n'
                            '\n'
                            'Personal information you disclose to us\n'
                            '\n'
                            'In Short: We collect personal information that you provide to us.\n'
                            '\n'
                            'We collect personal information that you voluntarily provide to us when you express an interest in obtaining information about us or our products and Services, when you participate in activities on the Services, or otherwise when you contact us.\n'
                            '\n'
                            'Sensitive Information. We do not process sensitive information.\n'
                            '\n'
                            'Application Data. If you use our application(s), we also may collect the following information if you choose to provide us with access or permission:\n'
                            'Mobile Device Data. We automatically collect device information (such as your mobile device ID, model, and manufacturer), operating system, version information and system configuration information, device and application identification numbers, browser type and version, hardware model Internet service provider and/or mobile carrier, and Internet Protocol (IP) address (or proxy server). If you are using our application(s), we may also collect information about the phone network associated with your mobile device, your mobile device’s operating system or platform, the type of mobile device you use, your mobile device’s unique device ID, and information about the features of our application(s) you accessed.\n'
                            'Push Notifications. We may request to send you push notifications regarding your account or certain features of the application(s). If you wish to opt out from receiving these types of communications, you may turn them off in your device\'s settings.\n'
                    'This information is primarily needed to maintain the security and operation of our application(s), for troubleshooting, and for our internal analytics and reporting purposes.\n'
                    '\n'
                    'All personal information that you provide to us must be true, complete, and accurate, and you must notify us of any changes to such personal information.\n'
                    '\n'
                    'Information automatically collected\n'
                        '\n'
                        'In Short: Some information — such as your Internet Protocol (IP) address and/or browser and device characteristics — is collected automatically when you visit our Services.\n'
                        '\n'
                        'We automatically collect certain information when you visit, use, or navigate the Services. This information does not reveal your specific identity (like your name or contact information) but may include device and usage information, such as your IP address, browser and device characteristics, operating system, language preferences, referring URLs, device name, country, location, information about how and when you use our Services, and other technical information. This information is primarily needed to maintain the security and operation of our Services, and for our internal analytics and reporting purposes.\n'
                    '\n'
                    'The information we collect includes:\n'
                    'Device Data. We collect device data such as information about your computer, phone, tablet, or other device you use to access the Services. Depending on the device used, this device data may include information such as your IP address (or proxy server), device and application identification numbers, location, browser type, hardware model, Internet service provider and/or mobile carrier, operating system, and system configuration information.\n'
                        'Location Data. We collect location data such as information about your device\'s location, which can be either precise or imprecise. How much information we collect depends on the type and settings of the device you use to access the Services. For example, we may use GPS and other technologies to collect geolocation data that tells us your current location (based on your IP address). You can opt out of allowing us to collect this information either by refusing access to the information or by disabling your Location setting on your device. However, if you choose to opt out, you may not be able to use certain aspects of the Services.\n'
                    '2. HOW DO WE PROCESS YOUR INFORMATION?\n'
                    '\n'
                    'In Short: We process your information to provide, improve, and administer our Services, communicate with you, for security and fraud prevention, and to comply with law. We may also process your information for other purposes with your consent.\n'
                    '\n'
                    'We process your personal information for a variety of reasons, depending on how you interact with our Services, including:\n'
                    '\n'
                    '\n'
                    '\n'
                    '\n'
                    'To save or protect an individual\'s vital interest. We may process your information when necessary to save or protect an individual’s vital interest, such as to prevent harm.\n'
                    'For Push Notifications. To enable push notifications\n'
                    '\n'
                    '3. WHAT LEGAL BASES DO WE RELY ON TO PROCESS YOUR INFORMATION?\n'
                    '\n'
                    'In Short: We only process your personal information when we believe it is necessary and we have a valid legal reason (i.e., legal basis) to do so under applicable law, like with your consent, to comply with laws, to provide you with services to enter into or fulfill our contractual obligations, to protect your rights, or to fulfill our legitimate business interests.\n'
                    '\n'
                    'If you are located in the EU or UK, this section applies to you.\n'
                    '\n'
                    'The General Data Protection Regulation (GDPR) and UK GDPR require us to explain the valid legal bases we rely on in order to process your personal information. As such, we may rely on the following legal bases to process your personal information:\n'
                    'Consent. We may process your information if you have given us permission (i.e., consent) to use your personal information for a specific purpose. You can withdraw your consent at any time. Click here to learn more.\n'
                    'Legitimate Interests. We may process your information when we believe it is reasonably necessary to achieve our legitimate business interests and those interests do not outweigh your interests and fundamental rights and freedoms. For example, we may process your personal information for some of the purposes described in order to:\n'
                    'In order to send a user notifications based about a printers status.\n'
                    'Legal Obligations. We may process your information where we believe it is necessary for compliance with our legal obligations, such as to cooperate with a law enforcement body or regulatory agency, exercise or defend our legal rights, or disclose your information as evidence in litigation in which we are involved.\n'
                    'Vital Interests. We may process your information where we believe it is necessary to protect your vital interests or the vital interests of a third party, such as situations involving potential threats to the safety of any person.\n'
                    '\n'
                    'If you are located in Canada, this section applies to you.\n'
                    '\n'
                    'We may process your information if you have given us specific permission (i.e., express consent) to use your personal information for a specific purpose, or in situations where your permission can be inferred (i.e., implied consent). You can withdraw your consent at any time. Click here to learn more.\n'
                    '\n'
                    'In some exceptional cases, we may be legally permitted under applicable law to process your information without your consent, including, for example:\n'
                    'If collection is clearly in the interests of an individual and consent cannot be obtained in a timely way\n'
                    'For investigations and fraud detection and prevention\n'
                    'For business transactions provided certain conditions are met\n'
                    'If it is contained in a witness statement and the collection is necessary to assess, process, or settle an insurance claim\n'
                    'For identifying injured, ill, or deceased persons and communicating with next of kin\n'
                    'If we have reasonable grounds to believe an individual has been, is, or may be victim of financial abuse\n'
                    'If it is reasonable to expect collection and use with consent would compromise the availability or the accuracy of the information and the collection is reasonable for purposes related to investigating a breach of an agreement or a contravention of the laws of Canada or a province\n'
                    'If disclosure is required to comply with a subpoena, warrant, court order, or rules of the court relating to the production of records\n'
                    'If it was produced by an individual in the course of their employment, business, or profession and the collection is consistent with the purposes for which the information was produced\n'
                    'If the collection is solely for journalistic, artistic, or literary purposes\n'
                    'If the information is publicly available and is specified by the regulations\n'
                    '\n'
                    '4. WHEN AND WITH WHOM DO WE SHARE YOUR PERSONAL INFORMATION?\n'
                    '\n'
                    'In Short: We may share information in specific situations described in this section and/or with the following categories of third parties.\n'
                    '\n'
                    'Vendors, Consultants, and Other Third-Party Service Providers. We may share your data with third-party vendors, service providers, contractors, or agents (“third parties”) who perform services for us or on our behalf and require access to such information to do that work. We have contracts in place with our third parties, which are designed to help safeguard your personal information. This means that they cannot do anything with your personal information unless we have instructed them to do it. They will also not share your personal information with any organization apart from us. They also commit to protect the data they hold on our behalf and to retain it for the period we instruct. The categories of third parties we may share personal information with are as follows:\n'
                    'Testing Tools\n'
                    'Performance Monitoring Tools\n'
                    'Push Notification Services\n'
                    'We also may need to share your personal information in the following situations:\n'
                    'Business Transfers. We may share or transfer your information in connection with, or during negotiations of, any merger, sale of company assets, financing, or acquisition of all or a portion of our business to another company.\n'
                    '\n'
                    '5. HOW LONG DO WE KEEP YOUR INFORMATION?\n'
                    '\n'
                    'In Short: We keep your information for as long as necessary to fulfill the purposes outlined in this privacy notice unless otherwise required by law.\n'
                    '\n'
                    'We will only keep your personal information for as long as it is necessary for the purposes set out in this privacy notice, unless a longer retention period is required or permitted by law (such as tax, accounting, or other legal requirements). No purpose in this notice will require us keeping your personal information for longer than 90 days.\n'
                    '\n'
                    'When we have no ongoing legitimate business need to process your personal information, we will either delete or anonymize such information, or, if this is not possible (for example, because your personal information has been stored in backup archives), then we will securely store your personal information and isolate it from any further processing until deletion is possible.\n'
                    '\n'
                    '6. HOW DO WE KEEP YOUR INFORMATION SAFE?\n'
                    '\n'
                    'In Short: We aim to protect your personal information through a system of organizational and technical security measures.\n'
                    '\n'
                    'We have implemented appropriate and reasonable technical and organizational security measures designed to protect the security of any personal information we process. However, despite our safeguards and efforts to secure your information, no electronic transmission over the Internet or information storage technology can be guaranteed to be 100% secure, so we cannot promise or guarantee that hackers, cybercriminals, or other unauthorized third parties will not be able to defeat our security and improperly collect, access, steal, or modify your information. Although we will do our best to protect your personal information, transmission of personal information to and from our Services is at your own risk. You should only access the Services within a secure environment.\n'
                    '\n'
                    '7. DO WE COLLECT INFORMATION FROM MINORS?\n'
                    '\n'
                    'In Short: We do not knowingly collect data from or market to children under 18 years of age.\n'
                    '\n'
                    'We do not knowingly solicit data from or market to children under 18 years of age. By using the Services, you represent that you are at least 18 or that you are the parent or guardian of such a minor and consent to such minor dependent’s use of the Services. If we learn that personal information from users less than 18 years of age has been collected, we will deactivate the account and take reasonable measures to promptly delete such data from our records. If you become aware of any data we may have collected from children under age 18, please contact us at ps_schmidt@yahoo.com.\n'
                    '\n'
                    '8. WHAT ARE YOUR PRIVACY RIGHTS?\n'
                    '\n'
                    'In Short: In some regions, such as the European Economic Area (EEA), United Kingdom (UK), and Canada, you have rights that allow you greater access to and control over your personal information. You may review, change, or terminate your account at any time.\n'
                    '\n'
                    'In some regions (like the EEA, UK, and Canada), you have certain rights under applicable data protection laws. These may include the right (i) to request access and obtain a copy of your personal information, (ii) to request rectification or erasure; (iii) to restrict the processing of your personal information; and (iv) if applicable, to data portability. In certain circumstances, you may also have the right to object to the processing of your personal information. You can make such a request by contacting us by using the contact details provided in the section “HOW CAN YOU CONTACT US ABOUT THIS NOTICE?” below.\n'
                    '\n'
                    'We will consider and act upon any request in accordance with applicable data protection laws.\n'
                    '\n'
                    'If you are located in the EEA or UK and you believe we are unlawfully processing your personal information, you also have the right to complain to your local data protection supervisory authority. You can find their contact details here: https://ec.europa.eu/justice/data-protection/bodies/authorities/index_en.htm.\n'
                    '\n'
                    'If you are located in Switzerland, the contact details for the data protection authorities are available here: https://www.edoeb.admin.ch/edoeb/en/home.html.\n'
                    '\n'
                    'Withdrawing your consent: If we are relying on your consent to process your personal information, which may be express and/or implied consent depending on the applicable law, you have the right to withdraw your consent at any time. You can withdraw your consent at any time by contacting us by using the contact details provided in the section "HOW CAN YOU CONTACT US ABOUT THIS NOTICE?" below.\n'
                    '\n'
                    'However, please note that this will not affect the lawfulness of the processing before its withdrawal, nor when applicable law allows, will it affect the processing of your personal information conducted in reliance on lawful processing grounds other than consent.\n'
                    '\n'
                    'If you have questions or comments about your privacy rights, you may email us at ps_schmidt@yahoo.com.\n'
                    '\n'
                    '9. CONTROLS FOR DO-NOT-TRACK FEATURES\n'
                    '\n'
                    'Most web browsers and some mobile operating systems and mobile applications include a Do-Not-Track ("DNT") feature or setting you can activate to signal your privacy preference not to have data about your online browsing activities monitored and collected. At this stage no uniform technology standard for recognizing and implementing DNT signals has been finalized. As such, we do not currently respond to DNT browser signals or any other mechanism that automatically communicates your choice not to be tracked online. If a standard for online tracking is adopted that we must follow in the future, we will inform you about that practice in a revised version of this privacy notice.\n'
                    '\n'
                    '10. DO CALIFORNIA RESIDENTS HAVE SPECIFIC PRIVACY RIGHTS?\n'
                    '\n'
                    'In Short: Yes, if you are a resident of California, you are granted specific rights regarding access to your personal information.\n'
                    '\n'
                    'California Civil Code Section 1798.83, also known as the "Shine The Light" law, permits our users who are California residents to request and obtain from us, once a year and free of charge, information about categories of personal information (if any) we disclosed to third parties for direct marketing purposes and the names and addresses of all third parties with which we shared personal information in the immediately preceding calendar year. If you are a California resident and would like to make such a request, please submit your request in writing to us using the contact information provided below.\n'
                    '\n'
                    'If you are under 18 years of age, reside in California, and have a registered account with Services, you have the right to request removal of unwanted data that you publicly post on the Services. To request removal of such data, please contact us using the contact information provided below and include the email address associated with your account and a statement that you reside in California. We will make sure the data is not publicly displayed on the Services, but please be aware that the data may not be completely or comprehensively removed from all our systems (e.g., backups, etc.).\n'
                    '\n'
                    '11. DO WE MAKE UPDATES TO THIS NOTICE?\n'
                    '\n'
                    'In Short: Yes, we will update this notice as necessary to stay compliant with relevant laws.\n'
                    '\n'
                    'We may update this privacy notice from time to time. The updated version will be indicated by an updated "Revised" date and the updated version will be effective as soon as it is accessible. If we make material changes to this privacy notice, we may notify you either by prominently posting a notice of such changes or by directly sending you a notification. We encourage you to review this privacy notice frequently to be informed of how we are protecting your information.\n'
                    '\n'
                    '12. HOW CAN YOU CONTACT US ABOUT THIS NOTICE?\n'
                    '\n'
                    'If you have questions or comments about this notice, you may email us at ps_schmidt@yahoo.com or by post to:\n'
                    '\n'
                    'Patrick Schmidt\n'
                    'Thüringer Str. 12\n'
                    'Mühltal, Hessen 64367\n'
                    'Germany\n'
                    '\n'
                    '13. HOW CAN YOU REVIEW, UPDATE, OR DELETE THE DATA WE COLLECT FROM YOU?\n'
                    '\n'
                    'Based on the applicable laws of your country, you may have the right to request access to the personal information we collect from you, change that information, or delete it in some circumstances. To request to review, update, or delete your personal information, please submit a request form by clicking here.\n'
                    'This privacy policy was created using Termly\'s Privacy Policy Generator.\n')
                  ])
            ]),
          ),
        ),
      );
}
