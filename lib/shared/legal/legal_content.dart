import '../../data/models/account.dart';
import 'legal_info.dart';

/// The Privacy Policy and Terms & Conditions, one complete document per
/// role (2026-11-20). Each role's document carries its own copy of the
/// shared sections, so a page never mixes in another role's content.
/// `**text**` renders bold.
enum LegalKind { privacy, terms }

sealed class LegalBlock {
  const LegalBlock();
}

class LegalHeading extends LegalBlock {
  const LegalHeading(this.text, {this.sub = false});
  final String text;
  final bool sub;
}

class LegalPara extends LegalBlock {
  const LegalPara(this.text);
  final String text;
}

class LegalBullets extends LegalBlock {
  const LegalBullets(this.items);
  final List<String> items;
}

class LegalCallout extends LegalBlock {
  const LegalCallout(this.lines);
  final List<String> lines;
}

class LegalDocument {
  const LegalDocument({required this.title, required this.blocks});
  final String title;
  final List<LegalBlock> blocks;
}

const _app = LegalInfo.app;
const _co = LegalInfo.company;

/// The four roles this app serves have their own pages; anything else
/// (no app session uses it) falls back to the Customer pages.
AppRole legalRoleFor(AppRole role) => switch (role) {
  AppRole.vendor || AppRole.driver || AppRole.manager => role,
  _ => AppRole.user,
};

String roleTitle(AppRole role) => switch (legalRoleFor(role)) {
  AppRole.vendor => 'Vendors',
  AppRole.driver => 'Delivery Partners',
  AppRole.manager => 'Territory Managers',
  _ => 'Customers',
};

String _roleSingular(AppRole role) => switch (role) {
  AppRole.vendor => 'Vendor',
  AppRole.driver => 'Delivery Partner',
  AppRole.manager => 'Territory Manager',
  _ => 'Customer',
};

LegalDocument legalDocument(LegalKind kind, AppRole role) => switch (kind) {
  LegalKind.privacy => LegalDocument(title: 'Privacy Policy', blocks: _privacy(legalRoleFor(role))),
  LegalKind.terms => LegalDocument(title: 'Terms & Conditions', blocks: _terms(legalRoleFor(role))),
};

// --- Shared sections ------------------------------------------------------

const List<LegalBlock> _contact = [
  LegalHeading('Contact and grievances'),
  LegalPara('$_co operates $_app.'),
  LegalPara('For questions, privacy requests, complaints or support, email **${LegalInfo.email}**.'),
  LegalPara('We acknowledge complaints within 48 hours and resolve them within one month of receipt.'),
];

List<LegalBlock> _privacyIntro(AppRole role) => [
  LegalPara(
    'This notice explains how $_co handles your information when you use $_app as a **${_roleSingular(role)}**. '
    'If you also use $_app in another role, the notice for that role covers that use.',
  ),
];

List<LegalBlock> _privacyCommon({String? maps}) => [
  const LegalHeading('Service providers'),
  const LegalPara('We use these providers to run $_app. They process information only to provide their service to us.'),
  LegalBullets([
    '**Google Firebase:** sign-in by phone number (Google receives your number to send the one-time code and to prevent abuse), data storage, file storage, server functions, push notifications, and App Check, which helps block fake apps.',
    if (maps != null) '**Google Maps Platform:** $maps',
  ]),
  const LegalPara(
    'We do not sell your personal data, and we do not use it for third-party advertising. '
    'We may disclose records to authorities when the law requires it.',
  ),
  const LegalHeading('How we protect it'),
  const LegalPara(
    'Access is limited by role: each person sees only what their part of the service needs. '
    'Data is encrypted in transit. Staff access to money and account records is logged.',
  ),
  const LegalHeading('How long we keep it'),
  const LegalPara(
    'We keep your information while your account is open. After that we keep only what the law, accounting, fraud prevention or an open '
    'dispute requires, and only for as long as it is needed.',
  ),
  const LegalHeading('Your choices and rights'),
  const LegalPara(
    'You can see and update most of your details in the app. To ask for a copy, a correction or deletion, or to raise a privacy concern, '
    'write to ${LegalInfo.email}. We may confirm your identity first. You can turn off optional permissions, such as location or '
    'notifications, in your phone\'s settings at any time; some features may then stop working.',
  ),
];

List<LegalBlock> _deletion({required String steps, required List<String> deleted, required List<String> kept, String? note}) => [
  const LegalHeading('Deleting your account'),
  LegalCallout([
    '**In the app:** $steps',
    '**Without the app:** email ${LegalInfo.email} from your registered details, with the mobile number on your account.',
  ]),
  const LegalPara(
    'Our team reviews each request within **2–3 working days**. While a request is waiting you can cancel it from the same screen. '
    'If something must be finished first, such as an order that is still in progress, we tell you what it is.',
  ),
  const LegalHeading('What we delete', sub: true),
  LegalBullets(deleted),
  const LegalHeading('What we keep, and why', sub: true),
  LegalBullets(kept),
  const LegalPara(
    'Kept records are needed for accounting, tax, fraud prevention or open disputes. Access to them is restricted, and they are deleted or '
    'anonymised when they are no longer needed. Deleting your account does not cancel a refund, settlement or other amount still owed by or to you.',
  ),
  if (note != null) LegalPara(note),
];

const _deletionRecord = 'A short record of the deletion itself: your name, number, role and the date.';
const _profileSteps = 'open **Profile** and tap **Delete account**.';

// --- Privacy, per role ----------------------------------------------------

List<LegalBlock> _privacy(AppRole role) => [
  ..._privacyIntro(role),
  ...switch (role) {
    AppRole.vendor => _privacyVendor,
    AppRole.driver => _privacyDriver,
    AppRole.manager => _privacyManager,
    _ => _privacyCustomer,
  },
  ..._contact,
];

final _privacyCustomer = <LegalBlock>[
  const LegalHeading('What we collect'),
  const LegalBullets([
    '**Account:** your name, mobile number, and email address if you give one.',
    '**Delivery addresses:** the addresses, map pins and delivery instructions you save.',
    '**Orders:** what you order, from which shop, the amounts, order status, and your ratings, reviews and support requests.',
    '**Payments:** the payment method you choose. For UPI paid directly to a shop, we record the payment reference needed to confirm it. We never ask for, or see, your UPI PIN or bank login.',
    '**Location (optional):** if you allow it, your phone\'s location, used to pin your address and to show nearby shops and delivery times. It is read on your phone when needed; we do not track you in the background.',
    '**Device:** a push notification token and basic app and device details, used to send order updates and fix problems.',
  ]),
  const LegalHeading('How we use it'),
  const LegalPara(
    'To create and secure your account, take and deliver your orders, show you shops in your area, send order updates, handle cancellations, refunds and support, and prevent fraud.',
  ),
  const LegalHeading('Who sees it'),
  const LegalBullets([
    '**The shop** you order from sees your name, order and delivery details.',
    '**The delivery partner** sees your name, phone number and delivery address for that order.',
    '**Your area\'s Territory Manager** and $_app staff can see order and support records to resolve problems.',
  ]),
  ..._privacyCommon(maps: 'maps, address search and turning a map pin into an address.'),
  ..._deletion(
    steps: _profileSteps,
    deleted: [
      'Your profile: name, mobile number, email address and photo.',
      'Your saved addresses, cart and recent searches.',
      'Your notifications and push notification tokens.',
      'Your sign-in, so the number can no longer log in to this account.',
    ],
    kept: ['Your past orders, payments and refunds, with the name and address on them.', 'Reviews and support tickets you created.', _deletionRecord],
  ),
];

final _privacyVendor = <LegalBlock>[
  const LegalHeading('What we collect'),
  const LegalBullets([
    '**Account:** the owner\'s name, mobile number and email address.',
    '**Business:** shop name, category, address and map location, opening hours, cover photo, and your product listings, prices, stock and photos.',
    '**Documents for review:** FSSAI licence, GST certificate, PAN card, and bank account or UPI details for payments, as your category requires.',
    '**Activity:** orders, cancellations and their reasons, refunds, commission, statements and settlements.',
    '**Location (optional):** your phone\'s location, only when you choose to use it to pin your shop\'s position.',
    '**Device:** a push notification token and basic app and device details.',
  ]),
  const LegalHeading('How we use it'),
  const LegalPara(
    'To review and approve your shop, publish your storefront, send you orders, calculate commission and settlements, handle refunds and disputes, and prevent fraud.',
  ),
  const LegalHeading('Who sees it'),
  const LegalBullets([
    '**Customers** see your approved storefront: shop name, address, hours, photos and products.',
    '**Delivery partners** see your shop\'s name, address and pickup details for their orders.',
    '**Your Territory Manager** and $_app staff see your documents, orders and settlements to review, support and audit your shop.',
  ]),
  ..._privacyCommon(maps: 'maps and address search for your shop location.'),
  ..._deletion(
    steps: _profileSteps,
    deleted: [
      'Your profile and storefront, so your shop no longer appears or takes new orders.',
      'Your products and product photos.',
      'Your cover photo and the documents you uploaded for review.',
      'Your notifications, push notification tokens and sign-in.',
    ],
    kept: [
      'Orders, invoices, cancellations and refunds.',
      'Commission, statement, settlement and transfer records.',
      'Reviews and support tickets.',
      _deletionRecord,
    ],
    note: 'Money still owed between you and $_app is settled through the normal settlement process.',
  ),
];

final _privacyDriver = <LegalBlock>[
  const LegalHeading('What we collect'),
  const LegalBullets([
    '**Account:** your name, mobile number, photo and email address.',
    '**Documents for review:** driving licence, Aadhaar or other ID proof, vehicle type and registration number, and bank account or UPI details for payouts.',
    '**Activity:** when you go on or off duty, the deliveries you accept and complete, pickup and delivery confirmations, cash collected on delivery, daily fees, earnings and payouts.',
    '**Location:** if you allow it, your phone\'s location is used on your phone to show where you are on the delivery map. We do not currently record or share your live location with customers or anyone else. If we turn live tracking on, we will update this notice and ask your permission first.',
    '**Device:** a push notification token and basic app and device details.',
  ]),
  const LegalHeading('How we use it'),
  const LegalPara(
    'To review and approve you, offer you deliveries, confirm pickups and drop-offs, reconcile cash on delivery, calculate fees and payouts, provide support, and keep deliveries safe.',
  ),
  const LegalHeading('Who sees it'),
  const LegalBullets([
    '**Customers** see your name and the progress of their delivery, and can contact you about it.',
    '**Shops** see who is collecting their order.',
    '**Your Territory Manager** and $_app staff see your documents, deliveries, cash and payouts to review, support and audit your work.',
  ]),
  ..._privacyCommon(maps: 'maps and directions for deliveries.'),
  ..._deletion(
    steps: _profileSteps,
    deleted: [
      'Your profile and photo, so you receive no new deliveries.',
      'The documents you uploaded for review.',
      'Your notifications, push notification tokens and sign-in.',
    ],
    kept: [
      'Delivery records and confirmations.',
      'Cash on delivery, daily fee, earnings and payout records.',
      'Incident and support records.',
      _deletionRecord,
    ],
    note: 'Hand over any cash on delivery you still hold before you ask to delete your account. It stays owed after deletion.',
  ),
];

final _privacyManager = <LegalBlock>[
  const LegalHeading('What we collect'),
  const LegalBullets([
    '**Account:** your name, mobile number, email address and photo.',
    '**Assignment:** the territory you manage and the shops and delivery partners in it.',
    '**Activity:** onboarding and review decisions, support handled, collections, transfers and settlements, and an audit history of the actions you take.',
    '**Device:** a push notification token and basic app and device details.',
  ]),
  const LegalHeading('How we use it'),
  const LegalPara('To give you access to your territory, record and reconcile money you collect and pay, and keep an accountable record of decisions.'),
  const LegalHeading('Who sees it'),
  const LegalBullets([
    '**Shops and delivery partners** in your territory see your name and contact details.',
    '**$_app staff** review your activity for support, financial reconciliation and accountability.',
  ]),
  ..._privacyCommon(),
  ..._deletion(
    steps: 'open **Profile**, or the side menu, and tap **Delete account**.',
    deleted: ['Your profile and photo.', 'Your access to the territory.', 'Your notifications, push notification tokens and sign-in.'],
    kept: ['Collection, transfer and settlement records.', 'The audit history of actions you took.', _deletionRecord],
    note:
        'The shops you manage must be handed to another Manager before your account can be deleted. The handover is handled separately from your privacy request.',
  ),
];

// --- Terms, per role ------------------------------------------------------

List<LegalBlock> _terms(AppRole role) => [
  LegalPara(
    'These terms apply when you use $_app as a **${_roleSingular(role)}**. $_app connects customers with local shops and delivery partners '
    'in the areas we serve. $_co operates the platform. By using $_app in this role you agree to these terms.',
  ),
  const LegalHeading('Your account'),
  const LegalBullets([
    'Give accurate information and keep it up to date.',
    'Keep your phone and one-time codes private. Never share a code with anyone, including people claiming to be from $_app.',
    'Report suspected unauthorised use to ${LegalInfo.email} straight away.',
  ]),
  ...switch (role) {
    AppRole.vendor => _termsVendor,
    AppRole.driver => _termsDriver,
    AppRole.manager => _termsManager,
    _ => _termsCustomer,
  },
  const LegalHeading('Not allowed'),
  const LegalPara('Fraud, harassment, sharing your account, accessing data you are not authorised to see, and misleading listings or records.'),
  const LegalHeading('Suspension'),
  const LegalPara(
    'We may restrict or suspend access for fraud, safety, security or a serious breach of these terms. Where appropriate and lawful, we tell you why and how to ask for a review.',
  ),
  const LegalHeading('Changes'),
  const LegalPara('We will tell you about important changes to these terms in the app or by another suitable channel.'),
  const LegalHeading('Governing law'),
  const LegalPara('These terms are governed by the laws of India. Nothing in them limits your rights under consumer protection law.'),
  ..._contact,
];

const _termsCustomer = <LegalBlock>[
  LegalHeading('Placing an order'),
  LegalBullets([
    'Check the items, delivery address, charges and payment method before you place an order. Checkout shows the item prices and any delivery and platform fees.',
    'The shop must accept your order. Items can sometimes be unavailable.',
    'Delivery times are estimates and can change with preparation time, weather, traffic and how many delivery partners are free.',
    'Substitutions or price changes need your approval.',
  ]),
  LegalHeading('Paying'),
  LegalBullets([
    'Use only the payment methods shown at checkout.',
    '**Cash on delivery:** pay the amount shown in the app when your order arrives.',
    '**UPI to the shop:** where offered, you pay the shop directly. Check that the payee shown matches the shop before you pay. $_app never asks for your UPI PIN.',
  ]),
  LegalHeading('Cancellations, refunds and problems'),
  LegalPara(
    'You can cancel a cash-on-delivery order from the app until the shop accepts it. For missing, damaged, wrong or undelivered items, '
    'contact support from the order with its order number. If a UPI order is cancelled or refunded, the refund is sent back to you by UPI '
    'and you can follow its progress in the order.',
  ),
];

const _termsVendor = <LegalBlock>[
  LegalHeading('Running your shop'),
  LegalBullets([
    'Keep your business details, prices, stock, opening hours and licences current.',
    'Sell only lawful goods, describe them accurately, and follow food safety, pharmacy, packaging and invoicing rules that apply to you.',
    'Accept an order only if you can fulfil it.',
    'Use customer details only to fulfil their order and for authorised support.',
  ]),
  LegalHeading('Cancellations and refunds'),
  LegalPara(
    'Record cancellations truthfully, and give a reason when you cancel an order you already accepted. Handle payments and refunds through '
    'the order and settlement process in the app, including UPI refunds owed to customers.',
  ),
  LegalHeading('Commission and settlements'),
  LegalPara(
    'You pay the commission and any other charges agreed with $_app. Report incorrect charges or settlement '
    'differences to your Territory Manager or to support.',
  ),
];

const _termsDriver = <LegalBlock>[
  LegalHeading('Deliveries'),
  LegalBullets([
    'Accept only deliveries you can complete safely and lawfully.',
    'Hold a valid driving licence, vehicle registration and insurance.',
    'Confirm each pickup and delivery in the app with its handover and delivery codes, and report problems promptly.',
    'Use customer details only for the delivery you are assigned.',
  ]),
  LegalHeading('Cash on delivery'),
  LegalPara('Collect only the amount shown in the app, and hand over the cash you collect as instructed.'),
  LegalHeading('Fees and payouts'),
  LegalPara(
    'A platform fee of ₹25 is charged for each day you go on duty. Report any difference in earnings, cash or delivery status to your Territory Manager or to support.',
  ),
];

const _termsManager = <LegalBlock>[
  LegalHeading('Managing your territory'),
  LegalBullets([
    'Manage only the shops, delivery partners, support and settlements in your assigned territory.',
    'Apply approved fees and rules, and record every collection and payment you make.',
    'Escalate disputes, incidents and refund cases that need company review.',
    'Make financial adjustments and access customer information only through the app\'s approved channels, which keep an audit trail.',
  ]),
  LegalHeading('When your assignment ends'),
  LegalPara(
    'Your territory access ends when your assignment closes. Hand over your shops and settle any pending work and money with the company as your agreement requires.',
  ),
];
