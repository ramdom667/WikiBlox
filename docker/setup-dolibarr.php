<?php
/**
 * Configuration de Dolibarr pour WikiCards (idempotent : relançable sans risque).
 * Exécuté DANS le conteneur par setup-dolibarr.sh :
 *   docker exec -i dolibarr_app php < docker/setup-dolibarr.php
 *
 * - Pays de la société (France) : nécessaire pour les taux de TVA
 * - Modules : API REST, Tiers, Produits, Stocks, Catégories
 * - Clé API de l'utilisateur admin (affichée sur la ligne APIKEY=...)
 * - Catégorie produit "WikiCards"
 * - Champs personnalisés (extrafields) des produits WikiCards
 * - Champ personnalisé roblox_user_id des tiers (joueurs)
 */
if (!defined('NOSESSION')) {
	define('NOSESSION', '1');
}
require '/var/www/html/master.inc.php';
require_once DOL_DOCUMENT_ROOT.'/core/lib/admin.lib.php';
require_once DOL_DOCUMENT_ROOT.'/core/class/extrafields.class.php';
require_once DOL_DOCUMENT_ROOT.'/categories/class/categorie.class.php';

$adminLogin = getenv('DOLI_ADMIN_LOGIN') ?: 'admin';
$categoryLabel = getenv('WIKICARDS_CATEGORY') ?: 'WikiCards';

if ($user->fetch(0, $adminLogin) <= 0) {
	fwrite(STDERR, "Utilisateur '$adminLogin' introuvable\n");
	exit(1);
}
$user->loadRights();

// 0. Mot de passe admin (WIKICARDS_ADMIN_PASSWORD) : réappliqué après restauration d'une base
$newPassword = getenv('WIKICARDS_ADMIN_PASSWORD');
if ($newPassword) {
	$res = $user->setPassword($user, $newPassword);
	if (!is_string($res) && $res < 0) {
		echo "[ERREUR] Mot de passe admin : ".$user->error."\n";
	} else {
		echo "[OK] Mot de passe admin appliqué\n";
	}
}

// 1. Société (pays requis pour les taux de TVA)
if (!getDolGlobalString('MAIN_INFO_SOCIETE_COUNTRY')) {
	dolibarr_set_const($db, 'MAIN_INFO_SOCIETE_COUNTRY', '1:FR:France', 'chaine', 0, '', $conf->entity);
}
if (!getDolGlobalString('MAIN_INFO_SOCIETE_NOM')) {
	dolibarr_set_const($db, 'MAIN_INFO_SOCIETE_NOM', 'WikiCards', 'chaine', 0, '', $conf->entity);
}
echo "[OK] Société configurée\n";

// 2. Modules
foreach (array('modSociete', 'modProduct', 'modStock', 'modCategorie', 'modApi') as $module) {
	$res = activateModule($module);
	if (!empty($res['errors'])) {
		echo "[ERREUR] $module : ".implode(' | ', $res['errors'])."\n";
	} else {
		echo "[OK] Module $module actif\n";
	}
}

// 3. Clé API admin (réutilisée si elle existe déjà)
// WIKICARDS_RESET_API_KEY=1 force une nouvelle clé : nécessaire après restauration d'une base
// sur une autre installation (la clé est chiffrée avec l'identifiant unique de l'instance).
$apiKey = getenv('WIKICARDS_RESET_API_KEY') ? '' : $user->api_key;
if (empty($apiKey) || !preg_match('/^[a-f0-9]{32}$/', $apiKey)) {
	$apiKey = bin2hex(random_bytes(16));
	$sql = "UPDATE ".MAIN_DB_PREFIX."user SET api_key = '".$db->escape(dolEncrypt($apiKey, '', '', 'dolibarr'))."'";
	$sql .= " WHERE rowid = ".((int) $user->id);
	if (!$db->query($sql)) {
		fwrite(STDERR, "Erreur clé API : ".$db->lasterror()."\n");
		exit(1);
	}
	echo "[OK] Clé API générée pour $adminLogin\n";
} else {
	echo "[OK] Clé API existante conservée pour $adminLogin\n";
}

// 4. Catégorie produit WikiCards
$cat = new Categorie($db);
if ($cat->fetch(0, $categoryLabel, Categorie::TYPE_PRODUCT) > 0) {
	echo "[OK] Catégorie '$categoryLabel' existe (id ".$cat->id.")\n";
} else {
	$cat = new Categorie($db);
	$cat->label = $categoryLabel;
	$cat->type = Categorie::TYPE_PRODUCT;
	$cat->description = 'Cartes Wikipédia du jeu WikiCards';
	$cat->color = '4CAF50';
	$cat->visible = 1;
	$id = $cat->create($user);
	echo $id > 0 ? "[OK] Catégorie '$categoryLabel' créée (id $id)\n" : "[ERREUR] Catégorie : ".$cat->error."\n";
}

// 5. Champs personnalisés produits (array_options.options_<nom>)
$extrafields = new ExtraFields($db);
$extrafields->fetch_name_optionals_label('product');
$fields = array(
	// nom => (label, type, taille, position)
	'wikipedia_page_id'          => array('Wikipedia page ID', 'int', '10', 100),
	'wikipedia_title'            => array('Wikipedia title', 'varchar', '255', 101),
	'wikicards_rarity'           => array('WikiCards rarity', 'varchar', '16', 102),
	'wikicards_total_views'      => array('WikiCards total views (3 months)', 'int', '10', 103),
	'wikicards_average_views'    => array('WikiCards average views', 'double', '24,2', 104),
	'wikicards_reference_months' => array('WikiCards reference months', 'varchar', '64', 105),
);
foreach ($fields as $name => $def) {
	if (!empty($extrafields->attributes['product']['label'][$name])) {
		echo "[OK] Extrafield $name existe\n";
		continue;
	}
	list($label, $type, $size, $pos) = $def;
	$res = $extrafields->addExtraField($name, $label, $type, $pos, $size, 'product', 0, 0, '', '', 1, '', '1');
	echo $res > 0 ? "[OK] Extrafield $name créé\n" : "[ERREUR] Extrafield $name : ".$extrafields->error."\n";
}

// 6. Champ personnalisé tiers : identifiant du joueur Roblox (unique)
$extrafields->fetch_name_optionals_label('societe');
if (!empty($extrafields->attributes['societe']['label']['roblox_user_id'])) {
	echo "[OK] Extrafield tiers roblox_user_id existe\n";
} else {
	$res = $extrafields->addExtraField('roblox_user_id', 'Roblox user ID', 'varchar', 100, '32', 'societe', 1, 0, '', '', 1, '', '1');
	echo $res > 0 ? "[OK] Extrafield tiers roblox_user_id créé\n" : "[ERREUR] Extrafield tiers roblox_user_id : ".$extrafields->error."\n";
}

echo "APIKEY=".$apiKey."\n";
