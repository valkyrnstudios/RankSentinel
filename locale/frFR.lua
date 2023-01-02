local addonName, _ = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "frFR")

if not L then return end

L[addonName] = "Rank Sentinel"

L["Notification"] = {
  ["random"] = false,
  ["default"] = {
    ["Prefix"] = {
      ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7.blp:0|t',
      ["Whisper"] = string.format("{rt7} %s d\195\169tect\195\169", addonName)
    },
    ["Base"] = "%s (Rang %d) utilis\195\169%s, il y a un nouveau rang au niveau %d.",
    ["Suffix"] = "v\195\169rifiez vos raccourcis la prochaine fois, ou voyez si un maitre a quelque chose \195\160 vous apprendre.",
    ["By"] = " par %s"
  },
  ["murloc"] = {
    ["Prefix"] = {
      ["Self"] = '|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4.blp:0|t',
      ["Whisper"] = "{rt4} Mmmrrglllm,"
    },
    ["Base"] = "nk mrrrggk %s %d%s urka %d.",
    ["Suffix"] = "Mmmm mrrrggk!",
    ["By"] = " mmgr %s"
  }
}

L["Cache"] = {
  ["Reset"] = "Cache vid\195\169: %d entr\195\169es purg\195\169es et %d rangs max oubli\195\169s",
  ["Queue"] = "mis en attente - %s, %s"
}

L["Broadcast"] = {
  ["Unrecognized"] = "communication non-reconnue(%s), votre ou %s client peut-être obsol\195\168te"
}

L["Cluster"] = {
  ["Lead"] = "Cluster Lead: %s",
  ["Sync"] = "Synchronisation des communications %d",
  ["Batch"] = "synchro l'ensemble %d \195\160 %d"
}

L["Utilities"] = {
  ["Upgrade"] = "Version du Addon chang\195\169, cache r\195\169initialis\195\169",
  ["IgnorePlayer"] = {
    ["Error"] = "Vous devez cibler un joueur",
    ["Ignored"] = "Ignor\195\169: %s",
    ["Unignored"] = "d\195\169-ignor\195\169: %s"
  },
  ["Outdated"] = "Version obsolète, fonctionnalité désactivée",
  ["NewVersion"] = "Nouvelle version disponible, veuillez mettre à jour pour réactiver"
}

L["ChatCommand"] = {
  ["Reset"] = "R\195\169glages reset",
  ["Count"] = {
    ["Spells"] = "Sorts attrap\195\169s: %d",
    ["Ranks"] = "Rangs mis en cache: %d"
  },
  ["Ignore"] = {
    ["Target"] = "Selectionnez une cible \195\160 ignorer",
    ["Count"] = "Ignore actuellement %d joueurs"
  },
  ["Queue"] = {
    ["Clear"] = "Vid\195\169 %d notifications en attente",
    ["Count"] = "Actuellement %d notifications en attente"
  },
  ["Report"] = {
    ["Header"] = "%sD\195\169tect\195\169 %d Rangs bas-niveau cette session",
    ["Summary"] = "%s - %s (Rang %d)",
    ["Unsupported"] = "Canal non-support\195\169 %s"
  },
  ["Flavor"] = {
    ["Set"] = "style de Notification r\195\169gl\195\169 sur: %s",
    ["Available"] = "Styles de notifications disponibles",
    ["Unavailable"] = "le Style %s n'est plus disponible, remis par d\195\169faut"
  }
}

L["Help"] = {
  ["title"] = "Options de ligne de commande",
  ["advanced"] = "Options de ligne de commande avanc\195\169es",
  ["enable"] = "toggle l'analyse du journal de combat",
  ["whisper"] = "toggle le chuchotement aux joueurs",
  ["reset"] = "reset le profil par d\195\169faut",
  ["count"] = "\195\169crit les statistiques actuelles",
  ["debug"] = "toggle le mode debug pour tests",
  ["clear"] = "remet \195\160 z\195\169ro le cache local des sorts",
  ["lead"] = "vous d\195\169fini comme leader",
  ["ignore"] = "ajoute la cible actuelle \195\160 la liste des ignor\195\169s du Addon, ne rapportera plus les erreurs de Rangs",
  ["queue"] = "\195\169crit les notifications en attente",
  ["queue clear"] = "vide les notifications en attente",
  ["queue process"] = "traite les notifications en attente",
  ["sync"] = "envoie le cache des annonces",
  ["report [channel]"] = "rapport des donn\195\169es de la session [self, say, party, raid, guild]",
  ["flavor"] = "liste les styles de notifications disponibles",
  ["flavor [option]"] = "r\195\168gle le style de notifications sur l'option"
}
