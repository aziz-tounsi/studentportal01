import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConsoleLanguage { en, fr }

class ConsoleLocaleNotifier extends Notifier<ConsoleLanguage> {
  static const String _prefKey = 'pythaone_console_lang';

  @override
  ConsoleLanguage build() {
    _loadFromPrefs();
    // Default language is English as requested by the user
    return ConsoleLanguage.en;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code == 'fr') {
        state = ConsoleLanguage.fr;
      } else if (code == 'en') {
        state = ConsoleLanguage.en;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(ConsoleLanguage lang) async {
    state = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang == ConsoleLanguage.fr ? 'fr' : 'en');
    } catch (_) {}
  }

  void toggle() {
    setLanguage(state == ConsoleLanguage.en ? ConsoleLanguage.fr : ConsoleLanguage.en);
  }
}

final consoleLocaleProvider =
    NotifierProvider<ConsoleLocaleNotifier, ConsoleLanguage>(
  ConsoleLocaleNotifier.new,
);

final consoleTranslationsProvider = Provider<ConsoleStrings>((ref) {
  final lang = ref.watch(consoleLocaleProvider);
  return lang == ConsoleLanguage.fr ? ConsoleStringsFr() : ConsoleStringsEn();
});

abstract class ConsoleStrings {
  // Navigation
  String get navPlatformTitle;
  String get navPlatformSubtitle;
  String get navSectionPlatform;
  String get navOverview;
  String get navSchools;
  String get navSectionBilling;
  String get navBilling;
  String get navAiTelemetry;
  String get navSectionControl;
  String get navAudit;
  String get navBugs;
  String get navSettings;
  String get navLogout;
  String get navLogoutConfirm;

  // Header
  String get searchPlaceholder;
  String get refreshTooltip;
  String get newSchoolBtn;
  String get manualInvoiceBtn;
  String get headerOverviewTitle;
  String get headerOverviewSubtitle;
  String get headerSchoolsTitle;
  String get headerSchoolsSubtitle;
  String get headerBillingTitle;
  String get headerBillingSubtitle;
  String get headerAiTitle;
  String get headerAiSubtitle;
  String get headerAuditTitle;
  String get headerAuditSubtitle;
  String get headerBugsTitle;
  String get headerBugsSubtitle;
  String get headerSettingsTitle;
  String get headerSettingsSubtitle;

  // Overview Page
  String get kpiActiveSchools;
  String get kpiTotalMrr;
  String get kpiAiTokensMonth;
  String get kpiOpenBugs;
  String get recentSchoolsTitle;
  String get recentSchoolsSubtitle;
  String get viewAll;
  String get noSchoolsRegistered;
  String get quickActionsTitle;
  String get quickActionAddSchool;
  String get quickActionAddSchoolDesc;
  String get quickActionIssueInvoice;
  String get quickActionIssueInvoiceDesc;
  String get quickActionAiKillSwitch;
  String get quickActionAiKillSwitchDesc;
  String get quickActionSettings;
  String get quickActionSettingsDesc;
  String get platformStatusTitle;
  String get systemOperational;
  String get databaseStatus;
  String get aiProxyStatus;
  String get storageStatus;
  String get connected;
  String get normal;

  // Schools Page
  String get filterAll;
  String get filterActive;
  String get filterSuspended;
  String get colSchool;
  String get colCode;
  String get colPlan;
  String get colStatus;
  String get colAiUsage;
  String get colActions;
  String get statusActive;
  String get statusSuspended;
  String get actionEditQuota;
  String get actionSuspend;
  String get actionActivate;
  String get modalAddSchoolTitle;
  String get schoolNameLabel;
  String get schoolCodeLabel;
  String get schoolEmailLabel;
  String get schoolPhoneLabel;
  String get schoolAddressLabel;
  String get schoolPlanLabel;
  String get schoolAdminEmailLabel;
  String get schoolAdminPasswordLabel;
  String get btnCreateSchool;
  String get modalQuotaTitle;
  String get monthlyBudgetUsdLabel;
  String get btnSaveQuota;
  String get confirmSuspendTitle;
  String get confirmSuspendDesc;
  String get confirmActivateTitle;
  String get confirmActivateDesc;

  // Billing Page
  String get mrrTitle;
  String get mrrSubtitle;
  String get paidTenantsCount;
  String get pendingInvoicesCount;
  String get plansSectionTitle;
  String get invoicesSectionTitle;
  String get colInvoiceNumber;
  String get colDueDate;
  String get colAmount;
  String get statusPaid;
  String get statusIssued;
  String get statusPending;
  String get statusOverdue;
  String get actionMarkPaid;
  String get modalManualInvoiceTitle;
  String get selectSchoolLabel;
  String get amountLabel;
  String get notesLabel;
  String get btnIssueInvoice;

  // AI Telemetry Page
  String get aiUsageTitle;
  String get totalTokensUsed;
  String get totalCostUsd;
  String get killSwitchCardTitle;
  String get killSwitchWarning;
  String get killSwitchStatusActive;
  String get killSwitchStatusBlocked;
  String get btnEngageKillSwitch;
  String get btnDisableKillSwitch;
  String get schoolAiBreakdownTitle;
  String get quotaExceededBadge;
  String get actionResetMonthlyQuota;

  // Audit Logs Page
  String get searchAuditLogs;
  String get filterByAction;
  String get colTimestamp;
  String get colActor;
  String get colActionName;
  String get colTargetSchool;
  String get colIpAddress;
  String get colDetails;
  String get noAuditLogsFound;

  // Bug Reports Page
  String get filterAllBugs;
  String get filterPendingBugs;
  String get filterInReviewBugs;
  String get filterResolvedBugs;
  String get colSubject;
  String get colReporter;
  String get colSchoolName;
  String get colSeverity;
  String get colCreated;
  String get modalUpdateStatusTitle;
  String get newStatusLabel;
  String get adminReplyLabel;
  String get btnUpdateStatus;

  // Settings Page
  String get settingsTitle;
  String get settingsSubtitle;
  String get tabLanguage;
  String get tabPlatform;
  String get tabSecurity;
  String get tabSystem;
  String get langChoiceTitle;
  String get langChoiceSubtitle;
  String get langEnName;
  String get langFrName;
  String get langChangedToast;
  String get platformConfigHeader;
  String get platformConfigSubtitle;
  String get fieldDefaultModel;
  String get fieldFallbackModel;
  String get fieldSupportEmail;
  String get fieldCurrency;
  String get btnSaveSettings;
  String get settingsSavedToast;
  String get adminProfileHeader;
  String get adminProfileSubtitle;
  String get adminFullName;
  String get adminEmail;
  String get adminRole;
  String get adminRolePill;
  String get systemInfoHeader;
  String get appVersion;
  String get flutterVersion;
  String get databaseHost;
  String get environment;
  String get prodEnv;

  // Login Page
  String get loginTitle;
  String get loginSubtitle;
  String get loginCardHeading;
  String get loginCardSubheading;
  String get emailLabel;
  String get emailPlaceholder;
  String get passwordLabel;
  String get btnSignIn;
  String get accessRestrictedNotice;
  String get loggingIn;

  // Common
  String get cancel;
  String get confirm;
  String get save;
  String get close;
  String get loading;
  String get success;
  String get error;
  String get delete;
}

class ConsoleStringsEn implements ConsoleStrings {
  @override
  String get navPlatformTitle => 'PythaOne';
  @override
  String get navPlatformSubtitle => 'Super Admin SaaS';
  @override
  String get navSectionPlatform => 'PLATFORM';
  @override
  String get navOverview => 'Overview';
  @override
  String get navSchools => 'Schools & Tenants';
  @override
  String get navSectionBilling => 'BILLING & AI';
  @override
  String get navBilling => 'Billing';
  @override
  String get navAiTelemetry => 'AI Telemetry';
  @override
  String get navSectionControl => 'CONTROL & SUPPORT';
  @override
  String get navAudit => 'Audit Logs';
  @override
  String get navBugs => 'Bug Reports';
  @override
  String get navSettings => 'Settings';
  @override
  String get navLogout => 'Sign Out';
  @override
  String get navLogoutConfirm => 'Are you sure you want to sign out?';

  @override
  String get searchPlaceholder => 'Search schools, slugs, subscriptions... [⌘K]';
  @override
  String get refreshTooltip => 'Refresh data';
  @override
  String get newSchoolBtn => 'New School';
  @override
  String get manualInvoiceBtn => 'Manual Invoice';
  @override
  String get headerOverviewTitle => 'Platform Overview';
  @override
  String get headerOverviewSubtitle =>
      'Global monitoring of SaaS tenants, revenue, and infrastructure';
  @override
  String get headerSchoolsTitle => 'Schools & Tenants';
  @override
  String get headerSchoolsSubtitle =>
      'Manage onboarded schools, branding, subscriptions, and access';
  @override
  String get headerBillingTitle => 'Billing & Subscriptions';
  @override
  String get headerBillingSubtitle =>
      'Monitor recurring revenue, validate wire transfers, and track invoices';
  @override
  String get headerAiTitle => 'AI Telemetry & Kill-Switch';
  @override
  String get headerAiSubtitle =>
      'Monitor token usage, per-school consumption, and global emergency stop';
  @override
  String get headerAuditTitle => 'Security & Audit Logs';
  @override
  String get headerAuditSubtitle =>
      'Full immutable audit trail of multi-tenant sensitive operations';
  @override
  String get headerBugsTitle => 'Bug Reports & Incidents';
  @override
  String get headerBugsSubtitle =>
      'Track and triage user and staff reported issues across tenant apps';
  @override
  String get headerSettingsTitle => 'Platform Settings';
  @override
  String get headerSettingsSubtitle =>
      'Configure system parameters, AI defaults, language preferences, and admin credentials';

  @override
  String get kpiActiveSchools => 'Active Schools';
  @override
  String get kpiTotalMrr => 'Total MRR';
  @override
  String get kpiAiTokensMonth => 'Monthly AI Tokens';
  @override
  String get kpiOpenBugs => 'Open Bug Reports';
  @override
  String get recentSchoolsTitle => 'Recent Schools';
  @override
  String get recentSchoolsSubtitle => 'Latest onboarded academic institutions';
  @override
  String get viewAll => 'View all';
  @override
  String get noSchoolsRegistered => 'No schools registered yet.';
  @override
  String get quickActionsTitle => 'Quick Actions';
  @override
  String get quickActionAddSchool => 'Add New School';
  @override
  String get quickActionAddSchoolDesc =>
      'Deploy new tenant database schema & credentials';
  @override
  String get quickActionIssueInvoice => 'Issue SaaS Invoice';
  @override
  String get quickActionIssueInvoiceDesc => 'Generate manual bill for a tenant';
  @override
  String get quickActionAiKillSwitch => 'AI Kill-Switch';
  @override
  String get quickActionAiKillSwitchDesc =>
      'Instantly stop all external LLM API proxies';
  @override
  String get quickActionSettings => 'Platform Settings';
  @override
  String get quickActionSettingsDesc =>
      'Manage platform configurations and language';
  @override
  String get platformStatusTitle => 'Infrastructure Status';
  @override
  String get systemOperational => 'All Systems Operational';
  @override
  String get databaseStatus => 'Supabase Cloud Database';
  @override
  String get aiProxyStatus => 'OpenRouter / Gemini AI Proxy';
  @override
  String get storageStatus => 'Media & Storage Cluster';
  @override
  String get connected => 'Connected';
  @override
  String get normal => 'Normal';

  @override
  String get filterAll => 'All';
  @override
  String get filterActive => 'Active';
  @override
  String get filterSuspended => 'Suspended';
  @override
  String get colSchool => 'School';
  @override
  String get colCode => 'Code / Slug';
  @override
  String get colPlan => 'Plan';
  @override
  String get colStatus => 'Status';
  @override
  String get colAiUsage => 'AI Usage';
  @override
  String get colActions => 'Actions';
  @override
  String get statusActive => 'Active';
  @override
  String get statusSuspended => 'Suspended';
  @override
  String get actionEditQuota => 'Edit AI Quota';
  @override
  String get actionSuspend => 'Suspend School';
  @override
  String get actionActivate => 'Activate School';
  @override
  String get modalAddSchoolTitle => 'Add New Academic Tenant';
  @override
  String get schoolNameLabel => 'School Name';
  @override
  String get schoolCodeLabel => 'Unique Code / Slug';
  @override
  String get schoolEmailLabel => 'Contact Email';
  @override
  String get schoolPhoneLabel => 'Phone Number';
  @override
  String get schoolAddressLabel => 'Physical Address';
  @override
  String get schoolPlanLabel => 'Subscription Plan';
  @override
  String get schoolAdminEmailLabel => 'Initial Admin Email';
  @override
  String get schoolAdminPasswordLabel => 'Initial Admin Password';
  @override
  String get btnCreateSchool => 'Create School Tenant';
  @override
  String get modalQuotaTitle => 'Edit Monthly AI Quota';
  @override
  String get monthlyBudgetUsdLabel => 'Monthly Budget (USD \$)';
  @override
  String get btnSaveQuota => 'Save Quota';
  @override
  String get confirmSuspendTitle => 'Suspend School';
  @override
  String get confirmSuspendDesc =>
      'Are you sure you want to suspend this school? All users from this school will be temporarily prevented from logging in.';
  @override
  String get confirmActivateTitle => 'Reactivate School';
  @override
  String get confirmActivateDesc =>
      'Reactivate this school and restore full platform access for its students, teachers, and admins?';

  @override
  String get mrrTitle => 'Monthly Recurring Revenue';
  @override
  String get mrrSubtitle => 'Total active subscriptions';
  @override
  String get paidTenantsCount => 'Paid Active Tenants';
  @override
  String get pendingInvoicesCount => 'Pending Invoices';
  @override
  String get plansSectionTitle => 'Subscription Plans';
  @override
  String get invoicesSectionTitle => 'Recent Invoices';
  @override
  String get colInvoiceNumber => 'Invoice #';
  @override
  String get colDueDate => 'Due Date';
  @override
  String get colAmount => 'Amount';
  @override
  String get statusPaid => 'Paid';
  @override
  String get statusIssued => 'Issued';
  @override
  String get statusPending => 'Pending';
  @override
  String get statusOverdue => 'Overdue';
  @override
  String get actionMarkPaid => 'Mark as Paid';
  @override
  String get modalManualInvoiceTitle => 'Issue Manual Invoice';
  @override
  String get selectSchoolLabel => 'Select School';
  @override
  String get amountLabel => 'Amount (TND)';
  @override
  String get notesLabel => 'Internal Notes';
  @override
  String get btnIssueInvoice => 'Issue Invoice';

  @override
  String get aiUsageTitle => 'Platform AI Usage';
  @override
  String get totalTokensUsed => 'Total Tokens (Current Month)';
  @override
  String get totalCostUsd => 'Total Spent (USD)';
  @override
  String get killSwitchCardTitle => 'Emergency AI Kill-Switch';
  @override
  String get killSwitchWarning =>
      'When enabled, all AI proxy requests across all schools will be immediately blocked.';
  @override
  String get killSwitchStatusActive => 'AI Proxy is Active & Operational';
  @override
  String get killSwitchStatusBlocked =>
      'KILL-SWITCH ENGAGED - ALL AI REQUESTS BLOCKED';
  @override
  String get btnEngageKillSwitch => 'Engage Kill-Switch';
  @override
  String get btnDisableKillSwitch => 'Resume AI Services';
  @override
  String get schoolAiBreakdownTitle => 'School AI Quotas & Usage';
  @override
  String get quotaExceededBadge => 'Quota Exceeded';
  @override
  String get actionResetMonthlyQuota => 'Reset Current Month';

  @override
  String get searchAuditLogs => 'Search action, admin, IP...';
  @override
  String get filterByAction => 'Filter by action';
  @override
  String get colTimestamp => 'Timestamp';
  @override
  String get colActor => 'Admin / Actor';
  @override
  String get colActionName => 'Action';
  @override
  String get colTargetSchool => 'Target School';
  @override
  String get colIpAddress => 'IP Address';
  @override
  String get colDetails => 'Metadata';
  @override
  String get noAuditLogsFound => 'No audit logs recorded matching this filter.';

  @override
  String get filterAllBugs => 'All Reports';
  @override
  String get filterPendingBugs => 'Pending';
  @override
  String get filterInReviewBugs => 'In Review';
  @override
  String get filterResolvedBugs => 'Resolved';
  @override
  String get colSubject => 'Subject / Issue';
  @override
  String get colReporter => 'Reporter';
  @override
  String get colSchoolName => 'School';
  @override
  String get colSeverity => 'Severity';
  @override
  String get colCreated => 'Date';
  @override
  String get modalUpdateStatusTitle => 'Update Bug Status';
  @override
  String get newStatusLabel => 'New Status';
  @override
  String get adminReplyLabel => 'Admin Note / Resolution Reply';
  @override
  String get btnUpdateStatus => 'Update Report';

  @override
  String get settingsTitle => 'Platform Settings';
  @override
  String get settingsSubtitle =>
      'Platform configurations, default models, language preferences & admin security';
  @override
  String get tabLanguage => 'Language & Region';
  @override
  String get tabPlatform => 'Global Platform Config';
  @override
  String get tabSecurity => 'Super Admin Account';
  @override
  String get tabSystem => 'System & Health';
  @override
  String get langChoiceTitle => 'Console Display Language';
  @override
  String get langChoiceSubtitle =>
      'Choose your preferred dashboard language. English is configured as your default developer language.';
  @override
  String get langEnName => 'English (US / Default)';
  @override
  String get langFrName => 'Français (French)';
  @override
  String get langChangedToast => 'Language switched to English';
  @override
  String get platformConfigHeader => 'Global SaaS Configuration';
  @override
  String get platformConfigSubtitle =>
      'Configure platform-wide AI models, support email, and operational currencies.';
  @override
  String get fieldDefaultModel => 'Default AI Model';
  @override
  String get fieldFallbackModel => 'Fallback AI Model';
  @override
  String get fieldSupportEmail => 'Platform Support Email';
  @override
  String get fieldCurrency => 'Platform Billing Currency';
  @override
  String get btnSaveSettings => 'Save Platform Settings';
  @override
  String get settingsSavedToast => 'Platform settings successfully saved!';
  @override
  String get adminProfileHeader => 'Super Administrator Profile';
  @override
  String get adminProfileSubtitle =>
      'Highest level platform owner credentials and active session info.';
  @override
  String get adminFullName => 'Full Name';
  @override
  String get adminEmail => 'Email Address';
  @override
  String get adminRole => 'Role';
  @override
  String get adminRolePill => 'SUPER_ADMIN (Full Platform Authority)';
  @override
  String get systemInfoHeader => 'System & Infrastructure Status';
  @override
  String get appVersion => 'Console Version';
  @override
  String get flutterVersion => 'Flutter Framework';
  @override
  String get databaseHost => 'Supabase Database Cluster';
  @override
  String get environment => 'Deployment Environment';
  @override
  String get prodEnv => 'Production / Multi-Tenant Live';

  @override
  String get loginTitle => 'PythaOne Console';
  @override
  String get loginSubtitle => 'SaaS Platform Owner Portal';
  @override
  String get loginCardHeading => 'Super Admin Sign In';
  @override
  String get loginCardSubheading =>
      'Restricted access for global multi-tenant platform control.';
  @override
  String get emailLabel => 'Email address';
  @override
  String get emailPlaceholder => 'admin@pythagore.tn';
  @override
  String get passwordLabel => 'Password';
  @override
  String get btnSignIn => 'Access Console';
  @override
  String get accessRestrictedNotice =>
      'Protected Super Admin Area • Unauthorized attempts are strictly logged';
  @override
  String get loggingIn => 'Authenticating...';

  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'Confirm';
  @override
  String get save => 'Save';
  @override
  String get close => 'Close';
  @override
  String get loading => 'Loading...';
  @override
  String get success => 'Success';
  @override
  String get error => 'Error';
  @override
  String get delete => 'Delete';
}

class ConsoleStringsFr implements ConsoleStrings {
  @override
  String get navPlatformTitle => 'PythaOne';
  @override
  String get navPlatformSubtitle => 'Super Admin SaaS';
  @override
  String get navSectionPlatform => 'PLATEFORME';
  @override
  String get navOverview => 'Vue d\'ensemble';
  @override
  String get navSchools => 'Écoles & Tenants';
  @override
  String get navSectionBilling => 'FACTURATION & IA';
  @override
  String get navBilling => 'Facturation';
  @override
  String get navAiTelemetry => 'Télémétrie IA';
  @override
  String get navSectionControl => 'CONTRÔLE & SUPPORT';
  @override
  String get navAudit => 'Journaux d\'Audit';
  @override
  String get navBugs => 'Signalements';
  @override
  String get navSettings => 'Paramètres';
  @override
  String get navLogout => 'Déconnexion';
  @override
  String get navLogoutConfirm =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get searchPlaceholder =>
      'Rechercher écoles, codes, abonnements... [⌘K]';
  @override
  String get refreshTooltip => 'Actualiser les données';
  @override
  String get newSchoolBtn => 'Nouvelle École';
  @override
  String get manualInvoiceBtn => 'Facture Manuelle';
  @override
  String get headerOverviewTitle => 'Vue d\'ensemble';
  @override
  String get headerOverviewSubtitle =>
      'Pilotage global de la plateforme SaaS et des établissements';
  @override
  String get headerSchoolsTitle => 'Écoles & Tenants';
  @override
  String get headerSchoolsSubtitle =>
      'Création, logos, abonnements et suspension des établissements';
  @override
  String get headerBillingTitle => 'Facturation & Paiements';
  @override
  String get headerBillingSubtitle =>
      'Validation des virements et suivi des factures SaaS';
  @override
  String get headerAiTitle => 'Télémétrie IA & Kill-Switch';
  @override
  String get headerAiSubtitle =>
      'Contrôle de la consommation et coupure d\'urgence plateforme';
  @override
  String get headerAuditTitle => 'Journaux d\'Audit';
  @override
  String get headerAuditSubtitle =>
      'Traçabilité complète des actions sensibles multi-tenants';
  @override
  String get headerBugsTitle => 'Signalements & Bugs';
  @override
  String get headerBugsSubtitle =>
      'Suivi des incidents remontés depuis les applications';
  @override
  String get headerSettingsTitle => 'Paramètres Plateforme';
  @override
  String get headerSettingsSubtitle =>
      'Configuration système, quotas IA, préférences de langue et profil super admin';

  @override
  String get kpiActiveSchools => 'Établissements Actifs';
  @override
  String get kpiTotalMrr => 'MRR Global';
  @override
  String get kpiAiTokensMonth => 'Tokens IA du mois';
  @override
  String get kpiOpenBugs => 'Signalements en attente';
  @override
  String get recentSchoolsTitle => 'Écoles Récemment Enregistrées';
  @override
  String get recentSchoolsSubtitle => 'Derniers établissements créés';
  @override
  String get viewAll => 'Voir tout';
  @override
  String get noSchoolsRegistered => 'Aucun établissement enregistré.';
  @override
  String get quickActionsTitle => 'Actions Rapides';
  @override
  String get quickActionAddSchool => 'Ajouter une école';
  @override
  String get quickActionAddSchoolDesc =>
      'Déployer un nouvel établissement avec schéma et accès';
  @override
  String get quickActionIssueInvoice => 'Émettre une facture';
  @override
  String get quickActionIssueInvoiceDesc =>
      'Générer une facture manuelle pour un établissement';
  @override
  String get quickActionAiKillSwitch => 'Kill-Switch IA';
  @override
  String get quickActionAiKillSwitchDesc =>
      'Couper immédiatement tous les proxys IA externes';
  @override
  String get quickActionSettings => 'Paramètres Plateforme';
  @override
  String get quickActionSettingsDesc =>
      'Gérer les configurations et la langue de la console';
  @override
  String get platformStatusTitle => 'Statut Infrastructure';
  @override
  String get systemOperational => 'Tous les systèmes opérationnels';
  @override
  String get databaseStatus => 'Base de données Supabase Cloud';
  @override
  String get aiProxyStatus => 'Proxy IA OpenRouter / Gemini';
  @override
  String get storageStatus => 'Stockage Médias & Fichiers';
  @override
  String get connected => 'Connecté';
  @override
  String get normal => 'Normal';

  @override
  String get filterAll => 'Tous';
  @override
  String get filterActive => 'Actifs';
  @override
  String get filterSuspended => 'Suspendus';
  @override
  String get colSchool => 'Établissement';
  @override
  String get colCode => 'Code / Slug';
  @override
  String get colPlan => 'Formule';
  @override
  String get colStatus => 'Statut SaaS';
  @override
  String get colAiUsage => 'Conso IA';
  @override
  String get colActions => 'Actions';
  @override
  String get statusActive => 'Actif';
  @override
  String get statusSuspended => 'Suspendu';
  @override
  String get actionEditQuota => 'Modifier Quota IA';
  @override
  String get actionSuspend => 'Suspendre École';
  @override
  String get actionActivate => 'Réactiver École';
  @override
  String get modalAddSchoolTitle => 'Créer un Nouvel Établissement';
  @override
  String get schoolNameLabel => 'Nom de l\'école';
  @override
  String get schoolCodeLabel => 'Code unique / Slug';
  @override
  String get schoolEmailLabel => 'Email de contact';
  @override
  String get schoolPhoneLabel => 'Numéro de téléphone';
  @override
  String get schoolAddressLabel => 'Adresse physique';
  @override
  String get schoolPlanLabel => 'Formule d\'abonnement';
  @override
  String get schoolAdminEmailLabel => 'Email administrateur initial';
  @override
  String get schoolAdminPasswordLabel => 'Mot de passe administrateur';
  @override
  String get btnCreateSchool => 'Créer l\'Établissement';
  @override
  String get modalQuotaTitle => 'Modifier le Quota IA Mensuel';
  @override
  String get monthlyBudgetUsdLabel => 'Budget mensuel (USD \$)';
  @override
  String get btnSaveQuota => 'Enregistrer le Quota';
  @override
  String get confirmSuspendTitle => 'Suspendre l\'école';
  @override
  String get confirmSuspendDesc =>
      'Êtes-vous sûr de vouloir suspendre cet établissement ? Tous ses utilisateurs seront temporairement bloqués.';
  @override
  String get confirmActivateTitle => 'Réactiver l\'école';
  @override
  String get confirmActivateDesc =>
      'Réactiver cet établissement et restaurer l\'accès complet aux élèves, enseignants et administrateurs ?';

  @override
  String get mrrTitle => 'Revenu Mensuel Récurrent';
  @override
  String get mrrSubtitle => 'Total abonnements actifs';
  @override
  String get paidTenantsCount => 'Écoles Payantes Actives';
  @override
  String get pendingInvoicesCount => 'Factures en Attente';
  @override
  String get plansSectionTitle => 'Formules & Forfaits SaaS';
  @override
  String get invoicesSectionTitle => 'Factures & Règlements';
  @override
  String get colInvoiceNumber => 'N° Facture';
  @override
  String get colDueDate => 'Date d\'échéance';
  @override
  String get colAmount => 'Montant';
  @override
  String get statusPaid => 'Payée';
  @override
  String get statusIssued => 'Émise';
  @override
  String get statusPending => 'En attente';
  @override
  String get statusOverdue => 'En retard';
  @override
  String get actionMarkPaid => 'Marquer Payée';
  @override
  String get modalManualInvoiceTitle => 'Émettre une Facture Manuelle';
  @override
  String get selectSchoolLabel => 'Sélectionner l\'école';
  @override
  String get amountLabel => 'Montant (TND)';
  @override
  String get notesLabel => 'Notes internes';
  @override
  String get btnIssueInvoice => 'Émettre la Facture';

  @override
  String get aiUsageTitle => 'Utilisation Globale de l\'IA';
  @override
  String get totalTokensUsed => 'Tokens Totaux (Mois en cours)';
  @override
  String get totalCostUsd => 'Coût Total (USD)';
  @override
  String get killSwitchCardTitle => 'Kill-Switch IA d\'Urgence';
  @override
  String get killSwitchWarning =>
      'Une fois activé, tous les appels aux proxys IA de tous les établissements seront coupés immédiatement.';
  @override
  String get killSwitchStatusActive => 'Le proxy IA est Actif et Opérationnel';
  @override
  String get killSwitchStatusBlocked =>
      'KILL-SWITCH ENGAGÉ - TOUS LES SERVICES IA SONT COUPÉS';
  @override
  String get btnEngageKillSwitch => 'Activer le Kill-Switch';
  @override
  String get btnDisableKillSwitch => 'Rétablir les Services IA';
  @override
  String get schoolAiBreakdownTitle =>
      'Consommation & Quotas par Établissement';
  @override
  String get quotaExceededBadge => 'Quota Dépassé';
  @override
  String get actionResetMonthlyQuota => 'Réinitialiser le Mois';

  @override
  String get searchAuditLogs => 'Rechercher action, admin, IP...';
  @override
  String get filterByAction => 'Filtrer par action';
  @override
  String get colTimestamp => 'Date & Heure';
  @override
  String get colActor => 'Administrateur / Auteur';
  @override
  String get colActionName => 'Action';
  @override
  String get colTargetSchool => 'Établissement Cible';
  @override
  String get colIpAddress => 'Adresse IP';
  @override
  String get colDetails => 'Détails';
  @override
  String get noAuditLogsFound =>
      'Aucun journal d\'audit trouvé pour ce filtre.';

  @override
  String get filterAllBugs => 'Tous';
  @override
  String get filterPendingBugs => 'En attente';
  @override
  String get filterInReviewBugs => 'En cours';
  @override
  String get filterResolvedBugs => 'Résolus';
  @override
  String get colSubject => 'Sujet / Problème';
  @override
  String get colReporter => 'Auteur';
  @override
  String get colSchoolName => 'Établissement';
  @override
  String get colSeverity => 'Gravité';
  @override
  String get colCreated => 'Date';
  @override
  String get modalUpdateStatusTitle =>
      'Mettre à jour le Statut du Signalement';
  @override
  String get newStatusLabel => 'Nouveau Statut';
  @override
  String get adminReplyLabel => 'Note ou Réponse de l\'Admin';
  @override
  String get btnUpdateStatus => 'Mettre à Jour';

  @override
  String get settingsTitle => 'Paramètres Plateforme';
  @override
  String get settingsSubtitle =>
      'Configuration système, quotas IA, préférences de langue et profil super admin';
  @override
  String get tabLanguage => 'Langue & Localisation';
  @override
  String get tabPlatform => 'Configuration Plateforme';
  @override
  String get tabSecurity => 'Compte Super Admin';
  @override
  String get tabSystem => 'Informations Système';
  @override
  String get langChoiceTitle => 'Langue d\'Affichage de la Console';
  @override
  String get langChoiceSubtitle =>
      'Choisissez votre langue de travail. L\'anglais est configuré comme langue par défaut pour le développement.';
  @override
  String get langEnName => 'English (Anglais / Par défaut)';
  @override
  String get langFrName => 'Français (French)';
  @override
  String get langChangedToast => 'Langue changée en Français';
  @override
  String get platformConfigHeader => 'Paramètres Globaux SaaS';
  @override
  String get platformConfigSubtitle =>
      'Configurez les modèles d\'IA globaux, l\'email de support et les devises de la plateforme.';
  @override
  String get fieldDefaultModel => 'Modèle IA par défaut';
  @override
  String get fieldFallbackModel => 'Modèle IA de secours';
  @override
  String get fieldSupportEmail => 'Email de support plateforme';
  @override
  String get fieldCurrency => 'Devise de facturation';
  @override
  String get btnSaveSettings => 'Enregistrer les Paramètres';
  @override
  String get settingsSavedToast =>
      'Paramètres de la plateforme enregistrés avec succès !';
  @override
  String get adminProfileHeader => 'Profil Super Administrateur';
  @override
  String get adminProfileSubtitle =>
      'Informations du compte propriétaire de la plateforme SaaS et session active.';
  @override
  String get adminFullName => 'Nom Complet';
  @override
  String get adminEmail => 'Adresse Email';
  @override
  String get adminRole => 'Rôle';
  @override
  String get adminRolePill => 'SUPER_ADMIN (Plein Pouvoir Plateforme)';
  @override
  String get systemInfoHeader => 'État du Système & Infrastructure';
  @override
  String get appVersion => 'Version Console';
  @override
  String get flutterVersion => 'Moteur Flutter';
  @override
  String get databaseHost => 'Cluster Base de Données Supabase';
  @override
  String get environment => 'Environnement';
  @override
  String get prodEnv => 'Production / Multi-Tenant Live';

  @override
  String get loginTitle => 'PythaOne Console';
  @override
  String get loginSubtitle => 'Portail Propriétaire SaaS';
  @override
  String get loginCardHeading => 'Connexion Super Admin';
  @override
  String get loginCardSubheading =>
      'Accès réservé au contrôle global des établissements.';
  @override
  String get emailLabel => 'Adresse email';
  @override
  String get emailPlaceholder => 'admin@pythagore.tn';
  @override
  String get passwordLabel => 'Mot de passe';
  @override
  String get btnSignIn => 'Accéder à la Console';
  @override
  String get accessRestrictedNotice =>
      'Espace Super Admin Protégé • Toute tentative non autorisée est tracée';
  @override
  String get loggingIn => 'Authentification en cours...';

  @override
  String get cancel => 'Annuler';
  @override
  String get confirm => 'Confirmer';
  @override
  String get save => 'Enregistrer';
  @override
  String get close => 'Fermer';
  @override
  String get loading => 'Chargement...';
  @override
  String get success => 'Succès';
  @override
  String get error => 'Erreur';
  @override
  String get delete => 'Supprimer';
}
