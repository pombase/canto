// @ts-check

"use strict";

/*global history,curs_root_uri,angular,$,make_ontology_complete_url,
  ferret_choose,application_root,window,curs_key,
  app_static_path,loadingStart,loadingEnd,alert,trim,read_only_curs */

var canto = angular.module('cantoApp', ['ui.bootstrap', 'angular-confirm', 'toaster',
  'chart.js'
]);

canto.config(['$compileProvider', function ($compileProvider) {
  $compileProvider.debugInfoEnabled(false);
}]);

var defaultStackedChartColors = [
  '#20C040', // green
  '#5080DD', // blue
  '#FDB42C', // yellow
  '#F7565A', // red
  '#B0B0B0', // grey
  '#CC8CCC', // purple
  '#3D8390', // dark bluegrey
];

var initialHideColumns = { // columns to hide because they're empty
  with_or_from_identifier: true, // set to false when a row has a non empty element
  qualifiers: true,
  submitter_comment: true,
  figure: true,
  extension: true,
  curator: true,
  evidence_code: true,
  conditions: true,
  genotype_name: true,
  genotype_background: true,
  term_suggestion: true,
  gene_product_form_id: true,
  strain_name: true,
};

canto.config(['ChartJsProvider', function (ChartJsProvider) {
  ChartJsProvider.setOptions({
    chartColors: defaultStackedChartColors
  });
}]);

canto.config(['$locationProvider', function($locationProvider) {
  $locationProvider.hashPrefix('');
}]);

var activeSessionStatuses = ['SESSION_CREATED', 'SESSION_ACCEPTED', 'CURATION_IN_PROGRESS', 'CURATION_PAUSED'];

function isActiveSession(state) {
  return $.inArray(state, activeSessionStatuses) >= 0;
}

function capitalizeFirstLetter(text) {
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function countKeys(o) {
  var size = 0,
    key;
  for (key in o) {
    if (o.hasOwnProperty(key)) {
      if (key.indexOf('$$') !== 0) {
        size++;
      }
    }
  }
  return size;
}

function arrayRemoveOne(array, item) {
  var i = array.indexOf(item);
  if (i >= 0) {
    array.splice(i, 1);
  }
}

function indexArray(array, keyFunction) {
  var indexObject = {};
  var i, key;
  for (i = 0; i < array.length; i += 1) {
    key = keyFunction(array[i]);
    if (indexObject.hasOwnProperty(key) === false) {
      indexObject[key] = [];
    }
    indexObject[key].push(array[i]);
  }
  return indexObject;
}

function copyObject(src, dest, keysFilter) {
  Object.getOwnPropertyNames(src).forEach(function (key) {
    if (key.indexOf('$$') === 0) {
      // ignore AngularJS data
      return;
    }
    if (keysFilter) {
      if (!keysFilter[key]) {
        return;
      }
    }

    if (null == src[key] || "object" != typeof src[key]) {
      dest[key] = src[key];
      return;
    }

    if (src[key] instanceof Array) {
      dest[key] = [];
      var len = src[key].length;
      var i;
      for (i = 0; i < len; i++) {
        dest[key][i] = src[key][i];
      }
      return;
    }

    if (src[key] instanceof Object) {
      dest[key] = {};
      copyObject(src[key], dest[key]);
    }
  });
}

// for each property in changedObj, copy to dest when it's different to origObj
function copyIfChanged(origObj, changedObj, dest) {
  Object.getOwnPropertyNames(changedObj).forEach(function (key) {
    if ((typeof (changedObj[key]) == 'undefined' || changedObj[key] == null) &&
      (typeof (origObj[key]) == 'undefined' || origObj[key] == null)) {
      return;
    }

    if (changedObj[key] !== origObj[key]) {
      if (origObj[key] instanceof Object && changedObj[key] instanceof Object &&
        angular.equals(origObj[key], changedObj[key])) {
        // same
      } else {
        dest[key] = changedObj[key];
      }
    }
  });
}

function simpleHttpPost(toaster, $http, url, data) {
  loadingStart();
  var promise = $http.post(url, data);
  promise.then(function (response) {
    var data = response.data;
    if (data.status === "success") {
      window.location.href = data.location;
    } else {
      toaster.pop('error', data.message);
    }
  }).
  catch(function (response) {
    var data = response.data;
    var status = response.status;
    var message;
    if (status == 404) {
      message = "Internal error: " + status;
    } else {
      message = "Accessing server failed: " + (data || status);
    }
    toaster.pop('error', message);
  }).
  finally(function () {
    loadingEnd();
  });

  return promise;
}

function conditionsToString(conditions) {
  return $.map(conditions, function (el) {
    return el.name;
  }).join(", ");
}

function conditionsToStringHighlightNew(conditions) {
  return $.map(conditions, function (el) {
    if (el.term_id) {
      return el.name;
    } else {
      return '<span style="color: red;">' + el.name + '</span>';
    }
  }).join(", ");
}

function isSingleLocusGenotype(genotype) {
  if (isWildTypeGenotype(genotype)) {
    return false;
  }
  return genotype.locus_count == 1;
}

function isMultiLocusGenotype(genotype) {
  if (isWildTypeGenotype(genotype)) {
    return false;
  }
  return genotype.locus_count > 1;
}

function isDiploidAllele(allele) {
  return allele.hasOwnProperty('diploid_name');
}

function isSingleLocusDiploid(genotype) {
  if (isWildTypeGenotype(genotype) || isMultiLocusGenotype(genotype)) {
    return false;
  }
  return isDiploidAllele(genotype.alleles[0]);
}

function isMultiLocusDiploid(genotype) {
  if (isWildTypeGenotype(genotype) || isSingleLocusGenotype(genotype)) {
    return false;
  }
  return genotype.alleles.some(isDiploidAllele);
}

function isWildTypeGenotype(genotype) {
  return genotype.alleles.length === 0;
}

function getGenotypeManagePath(organismMode) {
  var paths = {
    'unknown': 'genotype_manage',
    'normal': 'genotype_manage',
    'pathogen': 'pathogen_genotype_manage',
    'host': 'host_genotype_manage'
  };
  if (organismMode in paths) {
    return paths[organismMode];
  }
  return paths.normal;
}

function filterOrganisms(organisms, genotypeType) {
  if (genotypeType !== 'host' && genotypeType !== 'pathogen') {
    return organisms;
  }
  var byOrganismType = buildOrganismFilter(genotypeType);
  return organisms.filter(byOrganismType);

  function buildOrganismFilter(type) {
    return function (organism) {
      return organism.pathogen_or_host === type;
    };
  }
}

function filterStrainsByTaxonId(strains, taxonId) {
  var taxonIdNum = parseInt(taxonId, 10);
  return $.grep(strains, function (strain) {
    return strain.taxon_id === taxonIdNum;
  });
}

function sortByProperty(p) {
  return function(a, b) {
    if (a[p] < b[p]) {
      return -1;
    }
    if (a[p] > b[p]) {
      return 1;
    }
    return 0;
  };
}

canto.filter('breakExtensions', function () {
  return function (text) {
    if (text) {
      return text.replace(/,/g, ', ').replace(/\|/, " | ");
    }
    return '';
  };
});

canto.filter('toTrusted', ['$sce', function ($sce) {
  return function (text) {
    return $sce.trustAsHtml(text);
  };
}]);

canto.filter('addZeroWidthSpace', function () {
  return function (item) {
    if (item == null) {
      return null;
    }
    return item.replace(/,/g, ',&#8203;');
  };
});

canto.filter('wrapAtSpaces', function () {
  return function (item) {
    if (item == null) {
      return null;
    }
    return item.replace(/(\S+)/g, '<span style="white-space: nowrap">$1</span>');
  };
});

canto.filter('breakAtSpaces', function () {
  return function (item) {
    if (item == null) {
      return null;
    }
    return item.replace(/(\S\S)\s+(\S\S)/g, '$1<br/>$2');
  };
});

canto.filter('formatExpression', function () {
  return function (item) {
    if (item == null) {
      return null;
    }
    if (item.toLowerCase().indexOf('wild type') >= 0) {
      return 'Wild type level';
    } else {
      return item;
    }
  };
});

canto.filter('abbreviateGenus', function () {
  return function (scientificName) {
    return scientificName.replace(/^([a-z])\w+/i, '$1.');
  };
});

// from: https://stackoverflow.com/questions/15604140/replace-multiple-strings-with-multiple-other-strings
function multiReplaceAll(str,mapObj){
  var re = new RegExp(Object.keys(mapObj).join("|"),"gi");

  return str.replace(re, function(matched){
    return mapObj[matched.toLowerCase()];
  });
}

var greekCharMap = {
  "&agr;": "α",
  "&bgr;": "β",
  "&ggr;": "γ",
  "&dgr;": "δ",
  "&egr;": "ε",
  "&zgr;": "ζ",
  "&eegr;": "η",
  "&thgr;": "θ",
  "&igr;": "ι",
  "&kgr;": "κ",
  "&lgr;": "λ",
  "&mgr;": "μ",
  "&ngr;": "ν",
  "&xgr;": "ξ",
  "&ogr;": "ο",
  "&pgr;": "π",
  "&rgr;": "ρ",
  "&sgr;": "σ",
  "&tgr;": "τ",
  "&ugr;": "υ",
  "&phgr;": "φ",
  "&khgr;": "χ",
  "&psgr;": "ψ",
  "&ohgr;": "ω",
  "&Agr;": "Α",
  "&Bgr;": "Β",
  "&Ggr;": "Γ",
  "&Dgr;": "Δ",
  "&Egr;": "Ε",
  "&Zgr;": "Ζ",
  "&EEgr;": "Η",
  "&THgr;": "Θ",
  "&Igr;": "Ι",
  "&Kgr;": "Κ",
  "&Lgr;": "Λ",
  "&Mgr;": "Μ",
  "&Ngr;": "Ν",
  "&Xgr;": "Ξ",
  "&Ogr;": "Ο",
  "&Pgr;": "Π",
  "&Rgr;": "Ρ",
  "&Sgr;": "Σ",
  "&Tgr;": "Τ",
  "&Ugr;": "Υ",
  "&PHgr;": "Φ",
  "&KHgr;": "Χ",
  "&PSgr;": "Ψ",
  "&OHgr;": "Ω",
};

function encodeSymbol(argItem) {
  if (argItem == null) {
    return null;
  }
  var item = argItem.replace(/delta/g, '&Delta;');

  if (argItem.indexOf('&') >= 0) {
    item = multiReplaceAll(item, greekCharMap);
  }

  return item;
}

function symbolEncoder() {
  return encodeSymbol;
}

canto.filter('encodeAlleleSymbols', symbolEncoder);
canto.filter('encodeGeneSymbols', symbolEncoder);

canto.filter('featureChooserFilter', function () {
  return function (feature, showOrganism) {
    if (feature.metagenotype_id) {
      var pathogenPart = formatGenotype(feature.pathogen_genotype, showOrganism);
      var hostPart = formatGenotype(feature.host_genotype, showOrganism);
      return pathogenPart + ' / ' + hostPart;
    }
    return formatGenotype(feature, showOrganism);

    function formatGenotype(genotype, showOrganism) {
      var displayName = genotype.display_name;
      if (showOrganism) {
        displayName += ' ' + genotype.organism.full_name;
      }
      if (genotype.strain_name) {
        displayName += ' (' + genotype.strain_name + ')';
      }
      if (genotype.background) {
        displayName += ' ' + formatBackground(genotype.background);
      }
      return displayName;
    }

    function formatBackground(background) {
      var truncated = background.length > 15;
      return '(bkg: ' + background.substr(0, 15) + (truncated ? '...' : '') + ')';
    }
  };
});

canto.filter('renameGenotypeType', function () {
  return function (type) {
    if (type === 'pathogen' || type === 'host') {
      return capitalizeFirstLetter(type);
    }
    return 'Organism';
  };
});

canto.config(function ($logProvider) {
  $logProvider.debugEnabled(true);
});

function makeRangeScopeForRequest(rangeScope) {
  if ($.isArray(rangeScope)) {
    return '[' + rangeScope.join('|') + ']';
  }
  // special case for using the ontology namespace instead of
  // restricting to a subset using a term or terms
  return rangeScope;
}

canto.service('Curs', function ($http, $q) {
  this.list = function (key, args) {
    var data = null;

    if (!args) {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/list/';

    if (args.length > 0 && typeof (args[args.length - 1]) === 'object') {
      data = args.pop();
      return $http.post(url + args.join('/'), data)
        .then(function(response) {
          return response.data;
        });
    }
    // force IE not to cache
    var unique = '?u=' + (new Date()).getTime();
    return $http.get(url + args.join('/') + unique)
      .then(function(response) {
        return response.data;
      });
  };

  this.details = function (key, args) {
    var data = null;

    if (!args) {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/details/';

    if (args.length > 0 && typeof (args[args.length - 1]) === 'object') {
      data = args.pop();
      return $http.post(url + args.join('/'), data)
        .then(function(response) {
          return response.data;
        });
    }
    var unique = '?u=' + (new Date()).getTime();
    return $http.get(url + args.join('/') + unique)
      .then(function(response) {
        return response.data;
      });
  };

  this.add = function (key, args) {
    if (!args) {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/add/' + args.join('/');
    return $http.get(url)
      .then(function(response) {
        return response.data;
      });
  };

  this.set = function (key, args) {
    if (!args) {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/set/';

    var promise;

    if (args.length > 0 && typeof (args[args.length - 1]) === 'object') {
      var data = args.pop();
      promise = $http.post(url + args.join('/'), data);
    } else {
      promise = $http.get(url + args.join('/'));
    }

    return promise.then(function(response) {
      return response.data;
    });
  };

  this.delete = function (objectType, objectId, secondaryId) {
    var q = $q.defer();

    // POST the curs_key so that a crawled GET can't delete a feature
    // the key is checked on the server
    var details = {
      key: curs_key
    };

    var url = curs_root_uri + '/ws/' + objectType + '/delete/' + objectId;

    if (secondaryId) {
      url += '/' + secondaryId;
    }

    var putQ = $http.put(url, details);

    putQ.then(function (response) {
      if (response.data.status === 'success') {
        q.resolve();
      } else {
        q.reject(response.data.message);
      }
    }).catch(function (response) {
      q.reject('Deletion request failed: ' + response.status);
    });

    return q.promise;
  };
});

canto.service('CursGeneList', function ($q, Curs) {
  this.geneList = function () {
    var q = $q.defer();

    Curs.list('gene').then(function (genes) {
      $.map(genes,
        function (gene) {
          gene.feature_id = gene.gene_id;
        });
      q.resolve(genes);
    }).catch(function () {
      q.reject();
    });

    return q.promise;
  };

  this.getGeneById = function (geneId) {
    var genesPromise = this.geneList();
    return genesPromise.then(function (genes) {
      var filteredGenes = genes.filter(function (gene) {
        return gene.gene_id === geneId;
      });

      if (filteredGenes.length === 1) {
        return filteredGenes[0];
      } else {
        return null;
      }
    });
  };
});

canto.service('CursGenotypeList', function ($q, Curs) {
  function add_id_or_identifier(genotypes) {
    $.map(genotypes, function (genotype) {
      genotype.id_or_identifier = genotype.genotype_id || genotype.identifier;
      genotype.feature_id = genotype.genotype_id;
    });
  }

  var service = this;

  this.changeListeners = [];

  this.onListChange = function (callback) {
    this.changeListeners.push(callback);
  };

  this.sendChangeEvent = function () {
    $.map(service.changeListeners,
      function (callback) {
        callback();
      });
    service.changeListeners = [];
  };

  this.storeGenotype =
    function (toaster, $http, genotype_id, genotype_name, genotype_background, alleles, taxonid, strain_name, comment) {
      var promise = storeGenotypeHelper(toaster, $http, genotype_id, genotype_name, genotype_background, alleles, taxonid, strain_name, comment);

      promise.then(function () {
        service.sendChangeEvent();
      });

      return promise;
    };

  this.getGenotypeById = function (genotypeId) {
    var genotypesPromise = this.cursGenotypeList({
      include_allele: 1,
    });
    return genotypesPromise.then(function (genotypes) {
      var returnGenotypeList =
        $.grep(genotypes, function (genotype) {
          return genotype.genotype_id === genotypeId;
        });

      if (returnGenotypeList.length != 1) {
        return null;
      } else {
        return returnGenotypeList[0];
      }
    });
  };

  this.setGenotypeBackground = function (toaster, $http, genotype, newBackground) {
    return this.storeGenotype(toaster, $http, genotype.genotype_id, genotype.name,
                              newBackground, genotype.alleles, genotype.organism.taxonid,
                              genotype.strain_name, genotype.comment);
  };

  this.setGenotypeComment = function (toaster, $http, genotype, newComment) {
    return this.storeGenotype(toaster, $http, genotype.genotype_id, genotype.name,
                              genotype.background, genotype.alleles,
                              genotype.organism.taxonid,
                              genotype.strain_name, newComment);
  };

  this.cursGenotypeList = function (options) {
    var q = $q.defer();

    var cursGenotypesPromise = Curs.list('genotype', ['curs_only', options]);

    cursGenotypesPromise.then(function (genotypes) {
      add_id_or_identifier(genotypes);
      q.resolve(genotypes);
    }).catch(function (response) {
      if (response.status) {
        q.reject();
      } // otherwise the request was cancelled
    });

    return q.promise;
  };

  this.filteredGenotypeList = function (cursOrAll, filter) {
    var options = {
      filter: filter,
      include_allele: 1,
    };
    var filteredCursPromise =
      Curs.list('genotype', [cursOrAll, options]);

    var q = $q.defer();

    filteredCursPromise.then(function (genotypes) {
      add_id_or_identifier(genotypes);
      q.resolve(genotypes);
    }).catch(function (response) {
      if (response.status) {
        q.reject();
      } // otherwise the request was cancelled
    });

    return q.promise;
  };

  this.deleteGenotype = function (genotypeList, genotypeId) {
    var q = $q.defer();

    Curs.delete('genotype', genotypeId)
      .then(function () {
        for (var i = 0; i < genotypeList.length; i++) {
          if (genotypeList[i].genotype_id == genotypeId) {
            genotypeList.splice(i, 1);
            break;
          }
        }
        service.sendChangeEvent();
        q.resolve();
      })
      .catch(function (message) {
        q.reject(message);
      });

    return q.promise;
  };
});

canto.service('Metagenotype', function ($rootScope, $http, toaster, Curs) {

  var svc = this;
  svc.list = [];

  svc.create = function (data) {
    var storePromise = svc.store(data);

    storePromise.then(function successCallback(response) {
      switch (response.data.status) {
        case 'error':
          toaster.pop('error', response.data.message);
          break;

        case 'existing':
          toaster.pop('info', 'This metagenotype has already been created');
          break;

        case 'success':
          toaster.pop('success', 'This metagenotype has been created');
          svc.load();
          break;
      }
    }, function errorCallback() {
      toaster.pop('error', 'Failed to add metagenetype, could not contact the Canto server');
    });

  };

  svc.store = function (data) {
    var url = curs_root_uri + '/feature/metagenotype/store';

    return $http({
      method: 'POST',
      url: url,
      data: data
    });
  };

  svc.delete = function (id) {
    loadingStart();

    Curs.delete('metagenotype', id)
      .then(function () {
        toaster.pop('success', 'The metagenotype has been deleted');
        svc.load();

      }).catch(function (message) {
        if (message.match('metagenotype .* has annotations')) {
          toaster.pop('error', "couldn't delete the metagenotype: " +
            "delete the annotations that use it first");
        } else if (message.match('metagenotype .* used in extensions')) {
              toaster.pop('error', "couldn't delete the metagenotype: " +
                "delete the annotation extensions that use it first");
        } else {
          toaster.pop('error', "couldn't delete the metagenotype: " + message);
        }
      }).finally(function () {
        loadingEnd();
      });
  };

  svc.load = function () {
    var options = {
      include_allele: 1,
    };

    Curs.list('metagenotype', [options])
      .then(function (data) {
        svc.list = data;
        $rootScope.$broadcast('metagenotype:updated', svc.list);
      });
  };
});

canto.service('CursAlleleList', function ($q, Curs) {
  this.allAlleles = function() {
    return this.alleleNameComplete(':ALL:', ':ALL:');
  };

  this.alleleList = function (genePrimaryIdentifier) {
    return this.alleleNameComplete(genePrimaryIdentifier, ':ALL:');
  };

  this.alleleNameComplete = function (genePrimaryIdentifier, searchTerm) {
    var q = $q.defer();

    Curs.list('allele', [genePrimaryIdentifier, searchTerm])
      .then(function (alleles) {
        q.resolve(alleles);
      })
      .catch(function () {
        q.reject();
      });

    return q.promise;
  };
});

canto.service('CursConditionList', function ($q, Curs) {
  this.conditionList = function () {
    var q = $q.defer();

    Curs.list('condition').then(function (conditions) {
      q.resolve(conditions);
    }).catch(function () {
      q.reject();
    });

    return q.promise;
  };
});

canto.service('CursSessionDetails', function (Curs) {
  this.promise = Curs.details('session');

  this.get = function () {
    return this.promise;
  };
});

canto.service('CantoGlobals', function ($window) {
  this.app_static_path = $window.app_static_path;
  this.application_root = $window.application_root;
  this.curs_root_uri = $window.curs_root_uri;
  this.ferret_choose = $window.ferret_choose;
  this.read_only_curs = $window.read_only_curs;
  this.curs_session_state = $window.curs_session_state;
  this.is_admin_session = $window.is_admin_session;
  this.is_admin_user = $window.is_admin_user;
  this.current_user_is_admin = $window.current_user_is_admin;
  this.curationStatusData = $window.curationStatusData;
  this.cumulativeAnnotationTypeCounts = $window.cumulativeAnnotationTypeCounts;
  this.perPub5YearStatsData = $window.perPub5YearStatsData;
  this.htpPerPub5YearStatsData = $window.htpPerPub5YearStatsData;
  this.multi_organism_mode = $window.multi_organism_mode;
  this.split_genotypes_by_organism = $window.split_genotypes_by_organism;
  this.show_genotype_management_genes_list = $window.show_genotype_management_genes_list;
  this.strains_mode = $window.strains_mode;
  this.pathogen_host_mode = $window.pathogen_host_mode;
  this.alleles_have_expression = $window.alleles_have_expression;
  this.allow_single_wildtype_allele = $window.allow_single_wildtype_allele;
  this.diploid_mode = $window.diploid_mode;
  this.flybase_mode = $window.flybase_mode;
  this.max_term_name_select_count = $window.max_term_name_select_count;
  this.show_quick_deletion_buttons = $window.show_quick_deletion_buttons;
  this.show_quick_wild_type_buttons = $window.show_quick_wild_type_buttons;
  this.organismsAndGenes = $window.organismsAndGenes;
  this.confirmGenes = $window.confirmGenes;
  this.highlightTerms = $window.highlightTerms;
  this.geneListData = $window.geneListData;
  this.hostsWithNoGenes = $window.hostsWithNoGenes;
  this.annotationFigureField = $window.annotation_figure_field;
});

canto.service('CantoService', function ($http) {
  this.lookup = function (key, pathParts, params, timeout) {
    if (!pathParts) {
      pathParts = [];
    }

    if (!params) {
      params = {};
    }

    return $http.get(application_root + '/ws/lookup/' + key + '/' +
      pathParts.join('/'), {
        params: params,
        timeout: timeout
      })
      .then(function(response) {
        return response.data;
      });
  };

  this.details = function (key, params, timeout) {
    if (!params) {
      params = {};
    }

    return $http.get(application_root + '/ws/details/' + key, {
      params: params,
      timeout: timeout
    })
    .then(function(response) {
      return response.data;
    });
  };
});

var keysForServer = {
  extension: true,
  annotation_type: true,
  evidence_code: true,
  conditions: true,
  feature_id: true,
  feature_type: true,
  genotype_a_id: true,
  genotype_b_id: true,
  //  is_not: true,
  qualifiers: true,
  submitter_comment: true,
  figure: true,
  term_ontid: true,
  term_suggestion_name: true,
  term_suggestion_definition: true,
  with_gene_id: true,
  second_feature_id: true,
  second_feature_type: true,
  interacting_gene_id: true,
  interaction_annotations: true,
  interaction_annotations_with_phenotypes: true,
};

var annotationProxy =
  function (Curs, $q, $http) {
    var proxy = this;
    this.allQs = {};
    this.annotationsByType = {};

    this.getAnnotation = function (annotationTypeName) {
      if (!proxy.allQs[annotationTypeName]) {
        var q = $q.defer();
        proxy.allQs[annotationTypeName] = q.promise;

        var cursQ = Curs.list('annotation', [annotationTypeName]);

        cursQ.then(function (annotations) {
          proxy.annotationsByType[annotationTypeName] = annotations;
          q.resolve(annotations);
        });

        cursQ.catch(function (response) {
          if (response.status) {
            q.reject();
          } // otherwise the request was cancelled
        });
      }

      return proxy.allQs[annotationTypeName];
    };

    this.deleteAnnotation = function (annotation) {
      var q = $q.defer();

      var details = {
        key: curs_key,
        annotation_id: annotation.annotation_id
      };

      var putQ = $http.put(curs_root_uri + '/ws/annotation/delete', details);

      putQ.then(function (response) {
        if (response.data.status === 'success') {
          var annotations = proxy.annotationsByType[annotation.annotation_type];
          if (annotations) {
            var index = annotations.indexOf(annotation);
            if (index >= 0) {
              annotations.splice(index, 1);
            }
          }
          q.resolve();
        } else {
          q.reject(response.data.message);
        }
      }).catch(function (response) {
        q.reject('Deletion request failed: ' + response.status);
      });

      return q.promise;
    };

    this.storeChanges = function (annotation, changes, newly_added) {
      var q = $q.defer();

      var changesToStore = {};

      if (newly_added) {
        // special case, copy everything
        copyObject(changes, changesToStore, keysForServer);
      } else {
        copyIfChanged(annotation, changes, changesToStore);

        if (countKeys(changesToStore) === 0) {
          q.reject('No changes to store');
          return q.promise;
        }

        if (changesToStore.feature_id) {
          changesToStore.feature_type = annotation.feature_type;
        }
      }

      changesToStore.key = curs_key;

      // we send term_ontid, so this is not needed
      delete changesToStore.term_name;

      var putQ;

      if (newly_added) {
        putQ = $http.put(curs_root_uri + '/ws/annotation/create', changesToStore);
      } else {
        putQ = $http.put(curs_root_uri + '/ws/annotation/' + annotation.annotation_id +
          '/new/change', changesToStore);
      }
      putQ.then(function (response) {
        var data = response.data;
        if (data.status === 'success') {
          // update local copy
          copyObject(data.annotation, annotation);
          if (newly_added) {
            var annotations = proxy.annotationsByType[annotation.annotation_type];
            if (!annotations) {
              proxy.annotationsByType[annotation.annotation_type] = [];
              annotations = proxy.annotationsByType[annotation.annotation_type];
            }
            annotations.push(annotation);
          }
          q.resolve(annotation);
        } else {
          if (data.status === 'existing') {
            q.resolve('EXISTING');
          } else {
            q.reject(data.message);
          }
        }
      }).catch(function () {
        q.reject();
      });

      return q.promise;
    };

    this.newAnnotation = function(annotation) {
      return this.storeChanges({}, annotation, true);
    };
  };

canto.service('AnnotationProxy', ['Curs', '$q', '$http', annotationProxy]);

function fetch_conditions(conditionNamespace) {
  return function (search, showChoices) {
    $.ajax({
      url: make_ontology_complete_url(conditionNamespace),
      data: {
        term: search.term,
        def: 1,
      },
      dataType: "json",
      success: function (data) {
        var choices = $.map(data, function (item) {
          var label;
          if (typeof (item.matching_synonym) === 'undefined') {
            label = item.name;
          } else {
            label = item.name + ' (' + item.matching_synonym + ')';
          }
          return {
            label: label,
            value: item.name,
            name: item.name,
            definition: item.definition,
          };
        });
        showChoices(choices);
      },
    });
  };
}

var cursStateService =
  function () {
    // var gene = null

    this.searchString = null;
    this.termHistory = [];
    this.extension = [];
    this.comment = null;
    this.state = 'searching';
    this.evidence_code = '';
    this.conditions = [];
    this.with_gene_id = null;
    this.validEvidence = false;
    this.figure = null;
    this.termSuggestion = null;

    // return the data in a obj with keys keys suitable for sending to the
    // server
    this.asAnnotationDetails = function () {
      var retVal = {
        term_ontid: this.currentTerm(),
        evidence_code: this.evidence_code,
        with_gene_id: this.with_gene_id,
        conditions: this.conditions,
        term_suggestion_name: null,
        term_suggestion_definition: null,
        extension: this.extension,
        submitter_comment: this.comment,
        figure: this.figure,
      };

      if (this.termSuggestion) {
        retVal.term_suggestion_name = this.termSuggestion.name;
        retVal.term_suggestion_definition = this.termSuggestion.definition;
      }

      return retVal;
    };

    // clear the term picked by the term-name-complete and clear the history
    // of child terms we've navigated to
    this.clearTerm = function () {
      this.matchingSynonym = null;
      this.termHistory = [];
    };

    this.addTerm = function (termId) {
      this.termHistory.push(termId);
    };

    this.currentTerm = function () {
      if (this.termHistory.length > 0) {
        return this.termHistory[this.termHistory.length - 1];
      }
      return null;
    };

    this.gotoTerm = function (termId) {
      var i, value;
      for (i = 0; i < this.termHistory.length; i++) {
        value = this.termHistory[i];
        if (termId == value) {
          // truncate the array, making term_id the last element
          this.termHistory.length = i + 1;
          break;
        }
      }
    };

    this.setState = function (state) {
      this.state = state;
    };

    this.getState = function () {
      return this.state;
    };
  };

canto.service('CursStateService', ['$q', 'CantoService', cursStateService]);


var cursSettingsService =
  function ($http, $timeout, $q) {
    var service = this;

    this.data = {};

    this.getAll = function () {
      if (typeof (curs_root_uri) == 'undefined') {
        return {
          then: function (successCallback, errorCallback) {
            if (typeof (errorCallback) != 'undefined') {
              errorCallback();
            }
          },
        };
      }
      var unique = '?u=' + (new Date()).getTime();
      return $http.get(curs_root_uri + '/ws/settings/get_all' + unique);
    };

    this.set = function (key, value) {
      var q = $q.defer();

      var unique = '?u=' + (new Date()).getTime();
      var getRes = $http.post(curs_root_uri + '/ws/settings/set/' + key,
                              {
                                value: value
                              });

      getRes.then(function (response) {
        var result = response.data;
        if (result.status == 'success') {
          service.data[key] = value;
          q.resolve();
        } else {
          q.reject(result.message);
        }
      }).catch(function (response) {
        q.reject('request failed: ' + response.status);
      });

      return q.promise;
    };

    service.getAll().then(function (response) {
      $timeout(function () {
        service.data.annotation_mode = response.data.annotation_mode;
      });
    });

    this.getAnnotationMode = function () {
      return service.data.annotation_mode;
    };

    this.setAnnotationMode = function (mode) {
      service.set('annotation_mode', mode);
    };

    this.setAdvancedMode = function () {
      return service.setAnnotationMode('advanced');
    };

    this.setStandardMode = function () {
      return service.setAnnotationMode('standard');
    };
  };

canto.service('CursSettings', ['$http', '$timeout', '$q', cursSettingsService]);


var cursAnnotationDataService =
  function ($http) {
    var service = this;

    service.set = function (annotationId, key, value) {
      var unique = '?u=' + (new Date()).getTime();
      var url = curs_root_uri + '/ws/annotation/data/set/' + annotationId + '/' +
        key + '/' + value + unique;
      return $http.get(url);
    };
  };

canto.service('CursAnnotationDataService', ['$http', cursAnnotationDataService]);


var helpIcon = function (CantoGlobals, CantoConfig) {
  return {
    scope: {
      key: '@',
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/help_icon.html',
    controller: function ($scope) {
      $scope.helpText = null;

      $scope.app_static_path = CantoGlobals.app_static_path;

      $scope.click = function () {
        if ($scope.url) {
          window.open($scope.url, '_blank');
        }
      };

      CantoConfig.get('help_text').then(function (results) {
        if (results[$scope.key]) {
          if (results[$scope.key].docs_path) {
            $scope.url = CantoGlobals.application_root + '/docs/' + results[$scope.key].docs_path;
          }
          if (results[$scope.key].inline) {
            $scope.helpText = results[$scope.key].inline;
            if ($scope.url) {
              $scope.helpText += " (Click to visit documentation)";
            }
          }
        }
      });
    },
  };
};

canto.directive('helpIcon', ['CantoGlobals', 'CantoConfig', helpIcon]);

var cursFrontPageCtrl =
  function ($scope, $uibModal, CursSettings, CursAnnotationDataService,
            AnnotationProxy, AnnotationTypeConfig) {
    $scope.annotationTypes = [];
    $scope.annotationsByType = {};

    CursSettings.getAll().then(function (response) {
      $scope.messageForCurators = response.data.message_for_curators || '';
    });

    $scope.messageForCuratorsIsReady = function() {
      return $scope.messageForCurators !== undefined;
    };

    $scope.checkAll = function () {
      CursAnnotationDataService.set('all', 'checked', 'yes').
      then(function () {
        window.location.reload(false);
      });
    };
    $scope.clearAll = function () {
      CursAnnotationDataService.set('all', 'checked', 'no').
      then(function () {
        window.location.reload(false);
      });
    };

    $scope.viewMessageToCurators = function() {
      openSimpleDialog($uibModal, 'Message for curators',
                       'Message for curators',
                       $scope.messageForCurators);
    };

    $scope.enableSubmitButton = function() {
      var retVal = false;
      $.map($scope.annotationTypes,
            function(annotationType) {
              if ($scope.annotationsByType[annotationType.name] &&
                  $scope.annotationsByType[annotationType.name].length > 0) {
                retVal = true;
              }
            });
      return retVal;
    };

    $scope.editMessageToCurators = function () {
      editStoredMessage($uibModal, 'Edit message for curators',
                        $scope.messageForCurators,
                        'message_for_curators')
        .then(function(result) {
          if (typeof(result) !== 'undefined') {
            $scope.messageForCurators = result;
          }
        });
    };

    $scope.getAnnotationMode = function () {
      return CursSettings.getAnnotationMode();
    };

    AnnotationTypeConfig.getAll().then(function (data) {
      $scope.annotationTypes = data;

      $.map($scope.annotationTypes,
            function (annotationType) {
              AnnotationProxy.getAnnotation(annotationType.name)
                .then(function (annotations) {
                  $scope.annotationsByType[annotationType.name] = annotations;
                });
            });
    });
  };

canto.controller('CursFrontPageCtrl',
                 ['$scope', '$uibModal', 'CursSettings',
                  'CursAnnotationDataService', 'AnnotationProxy', 'AnnotationTypeConfig',
                  cursFrontPageCtrl]);


var cursPausedPageCtrl =
  function ($scope, $uibModal, CursSettings) {
    var settingsPromise = CursSettings.getAll();

    $scope.loading = true;
    $scope.pausedMessage = null;

    settingsPromise.then(function (response) {
      $scope.pausedMessage = response.data.paused_message;
      $scope.loading = false;
    });

    $scope.editMessage = function () {
      editStoredMessage($uibModal, 'Edit message',
                        $scope.pausedMessage,
                        'paused_message')
        .then(function(result) {
          $scope.pausedMessage = result;
        });
    };
  };

canto.controller('CursPausedPageCtrl',
                 ['$scope', '$uibModal', 'CursSettings',
                  cursPausedPageCtrl]);


function openSimpleDialog($uibModal, title, heading, message) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/simple_dialog.html',
    controller: 'SimpleDialogCtrl',
    title: title,
    resolve: {
      args: function() {
        return {
          heading: heading,
          message: message,
        };
      },
    },
    animate: false,
    windowClass: "modal",
    backdrop: 'static',
  });
}


var simpleDialogCtrl =
  function ($scope, $uibModalInstance, args) {
    $scope.heading = args.heading;
    $scope.message = args.message;

    $scope.close = function () {
      $uibModalInstance.dismiss('close');
    };
  };

canto.controller('SimpleDialogCtrl',
  ['$scope', '$uibModalInstance', 'args', simpleDialogCtrl]);

function openDeleteDialog($uibModal, title, heading, message) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/delete_dialog.html',
    controller: 'DeleteDialogCtrl',
    title: title,
    resolve: {
      args: function() {
        return {
          heading: heading,
          message: message,
        };
      },
    },
    animate: false,
    windowClass: "modal",
    backdrop: 'static',
  });
}

var DeleteDialogCtrl =
  function ($scope, $uibModalInstance, args) {
    $scope.heading = args.heading;
    $scope.message = args.message;

    $scope.onDelete = function () {
      $uibModalInstance.close('delete');
    };

    $scope.close = function () {
      $uibModalInstance.dismiss('close');
    };
  };

canto.controller(
  'DeleteDialogCtrl',
  ['$scope', '$uibModalInstance', 'args', DeleteDialogCtrl]
);

var pubmedIdStart =
  function ($http, toaster, CantoGlobals, CantoConfig) {
    return {
      scope: {},
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/pubmed_id_start.html',
      controller: function ($scope) {
        $scope.data = {
          searchId: null,
          results: null,
        };
        $scope.userIsAdmin = CantoGlobals.is_admin_user == "1";
        $scope.allowRestartApproval = false;
        $scope.publicationPageUrl = "";

        CantoConfig.get('public_mode')
          .then(function (data) {
            $scope.publicMode = data.value != "0";
          });

        $scope.search = function () {
          loadingStart();
          var url =
            CantoGlobals.application_root +
            '/tools/pubmed_id_lookup?pubmed-id-lookup-input=' + $scope.data.searchId;
          var promise = $http.post(url);
          promise.then(function (response) {
            var results = response.data;
            if (results.message) {
              toaster.pop('error', results.message);
            } else {
              $scope.data.results = results;
              $scope.publicationPageUrl = getPublicationPageUrl();
              $scope.allowRestartApproval = getRestartApprovalPermission();
            }
          }).
          catch(function (response) {
            var data = response.data;
            var status = response.status;
            var message;
            if (status == 404) {
              message = "Internal error: " + status;
            } else {
              message = "Accessing server failed: " + (data || status);
            }
            toaster.pop('error', message);
          }).
          finally(function () {
            loadingEnd();
          });
        };

        $scope.findAnother = function () {
          $scope.data.results = null;
        };

        $scope.startCuration = function () {
          var root = CantoGlobals.application_root;
          loadingStart();
          if ($scope.data.results.sessions.length > 0) {
            var sessionId = $scope.data.results.sessions[0].session;
            if ($scope.publicMode) {
              window.location.href = root + '/curs/' + sessionId;
            } else {
              window.location.href = root + '/curs/' + sessionId + '/ro';
            }
          } else {
            var publicationName = $scope.data.results.pub.uniquename;
            window.location.href = root + '/tools/start/' + publicationName;
          }
        };

        $scope.restartApproval = function () {
          var sessionId = $scope.data.results.sessions[0].session;
          var sessionLink = (
            CantoGlobals.application_root + '/curs/' + sessionId + '/restart_approval/'
          );
          if ($scope.allowRestartApproval) {
            window.location.href = sessionLink;
          }
        };

        function getPublicationPageUrl() {
          var url = "";
          if ($scope.userIsAdmin && $scope.data.results) {
            var pubId = $scope.data.results.pub.pub_id;
            url = (
              CantoGlobals.application_root +
              '/view/object/pub/' + pubId +
              '?model=track'
            );
          }
          return url;
        }

        function getRestartApprovalPermission() {
          var sessionExists = ($scope.data.results && $scope.data.results.sessions.length > 0);
          if ($scope.userIsAdmin && sessionExists) {
            var sessionState = $scope.data.results.sessions[0].state;
            return sessionState == 'APPROVED';
          }
          return false;
        }
      }
    };
  };

canto.directive('pubmedIdStart',
  ['$http', 'toaster', 'CantoGlobals', 'CantoConfig', pubmedIdStart]);


var advancedModeToggle =
  function (CursSettings) {
    return {
      scope: {},
      restrict: 'E',
      replace: true,
      template: '<label ng-click="$event.stopPropagation()"><input ng-change="change()" ng-model="advanced" type="checkbox"/>Advanced mode</label>',
      controller: function ($scope) {
        $scope.CursSettings = CursSettings;

        $scope.advanced = CursSettings.getAnnotationMode() == 'advanced';

        $scope.$watch('CursSettings.getAnnotationMode()',
          function (newValue) {
            $scope.advanced = newValue == 'advanced';
          });

        $scope.change = function () {
          if ($scope.advanced) {
            CursSettings.setAdvancedMode();
          } else {
            CursSettings.setStandardMode();
          }
        };
      }
    };
  };

canto.directive('advancedModeToggle', ['CursSettings', advancedModeToggle]);


var breadcrumbsDirective =
  function ($compile, CursStateService, CantoService) {
    return {
      scope: {},
      restrict: 'E',
      replace: true,
      controller: function ($scope) {
        $scope.CursStateService = CursStateService;

        $scope.termDetails = {};

        $scope.clearTerms = function () {
          CursStateService.clearTerm();
          CursStateService.setState('searching');
        };

        $scope.gotoTerm = function (termId) {
          CursStateService.gotoTerm(termId);
        };

        $scope.currentTerm = function () {
          return CursStateService.currentTerm();
        };

        $scope.lookupPromise = function (termId) {
          return CantoService.lookup('ontology', [termId], {
            def: 1,
          });
        };

        $scope.lookupProcess = function (data) {
          if (!data.children || data.children.length == 0) {
            data.children = null;
          }
          if (!data.synonyms || data.synonyms.length == 0) {
            data.synonyms = null;
          } else {
            data.synonyms = $.map(data.synonyms,
              function (synonym) {
                return synonym.name;
              });
          }

          $scope.termDetails[data.id] = data;

          $scope.render();
        };

        $scope.render = function () {
          var html = '';

          var i, termId, termDetails, makeLink, termText;
          var termHistory = CursStateService.termHistory;
          for (i = 0; i < termHistory.length; i++) {
            termId = termHistory[i];
            makeLink = (i != termHistory.length - 1);

            html += '<div class="breadcrumbs-link">';

            termDetails = $scope.termDetails[termId];
            if (termDetails) {
              termText = termId + ' - ' + termDetails.name;
            } else {
              termText = termId;
            }

            if (makeLink) {
              html += '<a href="#" ng-click="' +
                "gotoTerm('" + termId + "'" + ')">';
            }

            html += '<initially-hidden-text text="' + termText +
              '" link-label="..." preview-char-count="40"></initially-hidden-text>';

            if (makeLink) {
              html += '</a>';
            }
          }

          for (i = 0; i < termHistory.length; i++) {
            html += '</div>';
          }

          $('#breadcrumb-terms').html($compile(html)($scope));
        };
      },
      link: function ($scope) {
        $scope.$watch('currentTerm()',
          function (newTermId) {
            if (newTermId) {
              if (!$scope.termDetails[newTermId]) {
                $scope.lookupPromise(newTermId).then(function (data) {
                  $scope.lookupProcess(data);
                });
              }
            }

            $scope.render();
          });

      },
      templateUrl: app_static_path + 'ng_templates/breadcrumbs.html',
    };
  };

canto.directive('breadcrumbs', ['$compile', 'CursStateService', 'CantoService',
  breadcrumbsDirective
]);


function openSingleGeneAddDialog($uibModal) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/single_gene_add.html',
    controller: 'SingleGeneAddDialogCtrl',
    title: 'Add a new gene by name or identifier',
    animate: false,
    windowClass: "modal",
    backdrop: 'static',
  });
}


function featureChooserControlHelper($scope, $uibModal, CursGeneList,
                                     CursGenotypeList, Curs, toaster) {
    $scope.$watch('chosenFeatureId',
      function (newFeatureId) {
        if (newFeatureId && $scope.features) {
          $.map($scope.features,
            function (feature) {
              if (feature.feature_id == newFeatureId) {
                if ($scope.chosenFeatureUniquename !== undefined) {
                  $scope.chosenFeatureUniquename = feature.primary_identifier;
                }
                if ($scope.chosenFeatureDisplayName !== undefined) {
                  $scope.chosenFeatureDisplayName = feature.display_name;
                }
              }
            });
        }
      });
}


var multiFeatureChooser =
  function ($uibModal, CantoGlobals, CursGeneList, CursGenotypeList, Curs, toaster) {
    return {
      scope: {
        features: '=',
        featureType: '@',
        selectedFeatureIds: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function ($scope) {
        featureChooserControlHelper($scope, $uibModal, CursGeneList,
          CursGenotypeList, Curs, toaster);

        $scope.showOrganism = CantoGlobals.multi_organism_mode;

        $scope.toggleSelection = function toggleSelection(featureId) {
          var idx = $scope.selectedFeatureIds.indexOf(featureId);

          // is currently selected
          if (idx > -1) {
            $scope.selectedFeatureIds.splice(idx, 1);
          }

          // is newly selected
          else {
            $scope.selectedFeatureIds.push(featureId);
          }
        };

        $scope.selectNone = () => {
          $scope.selectedFeatureIds.length = 0;
        };

        $scope.selectAll = () => {
          $scope.selectNone();
          $.map($scope.features,
                (feature) => $scope.selectedFeatureIds.push(feature.feature_id));
        };

      },
      templateUrl: app_static_path + 'ng_templates/multi_feature_chooser.html',
    };
  };

canto.directive('multiFeatureChooser',
  ['$uibModal', 'CantoGlobals', 'CursGeneList', 'CursGenotypeList', 'Curs', 'toaster',
    multiFeatureChooser
  ]);


var featureChooser =
  function ($uibModal, CursGeneList, CursGenotypeList, Curs, CantoGlobals, toaster) {
    return {
      scope: {
        features: '=',
        featureType: '@',
        featureEditable: '=',
        chosenFeatureId: '=',
        chosenFeatureUniquename: '=',
        chosenFeatureDisplayName: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.showOrganism = CantoGlobals.multi_organism_mode;
        $scope.showCompleter = false;

        $scope.search = function() {
          $scope.showCompleter = !$scope.showCompleter;
        };

        $scope.chosenFeature = function() {
          if ($scope.chosenFeatureId) {
            for (const feature of $scope.features) {
              if (feature.feature_id === $scope.chosenFeatureId) {
                return feature;
              }
            }
          }

          return null;
        };

        $scope.featureIsEditable = function() {
          if (typeof($scope.featureEditable) === 'undefined') {
            // default to editable
            return true;
          } else {
            return $scope.featureEditable;
          }
        };

        $scope.featureDisplayName = function() {
          const chosenFeature = $scope.chosenFeature();

          if (chosenFeature) {
            return chosenFeature.display_name;
          }

          return 'UNKNOWN';
        };

        featureChooserControlHelper($scope, $uibModal, CursGeneList, CursGenotypeList,
          Curs, toaster);

        $scope.foundCallback = function (featureId) {
          $scope.chosenFeatureId = featureId;
          $scope.showCompleter = false;
        };
      },
      templateUrl: app_static_path + 'ng_templates/feature_chooser.html',
    };
  };

canto.directive('featureChooser',
                ['$uibModal', 'CursGeneList', 'CursGenotypeList', 'Curs', 'CantoGlobals', 'toaster',
    featureChooser
  ]);


var featureComplete =
  function($timeout, CantoGlobals) {
    return {
      scope: {
        featureType: '@',
        features: '=',
        foundCallback: '&',
      },
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;

        $scope.render_item =
          function (ul, item, search_string) {
            return $("<li></li>")
              .data("item.autocomplete", item)
              .append("<a>" + item.label + "</a>")
              .appendTo(ul);
          };
      },
      replace: true,
      restrict: 'E',
      templateUrl: app_static_path + 'ng_templates/feature_complete.html',
      link: function ($scope, elem) {
        var input = $(elem).find('input');

        $scope.selectedFeatureId = null;

        var source =
          $.map($scope.features,
                function(feature) {
                  return {
                    label: feature.display_name,
                    value: feature.display_name,
                    id: feature.feature_id,
                  };
                });

        input.autocomplete({
          minLength: 1,
          source: function(request, response) {
            var searchVal = request.term.trim().toLowerCase();
            if (searchVal.length > 0) {
              response($.grep(source,
                              function(item) {
                                return item.label.toLowerCase().indexOf(searchVal) != -1;
                              }));
            } else {
              response([]);
            }
          },
          select: function (event, ui) {
            $timeout(function () {
              $scope.foundCallback({
                featureId: ui.item.id,
              });
            }, 1);
          },
        }).data("autocomplete")._renderItem = function (ul, item) {
          var search_string = input.val();
          return $scope.render_item(ul, item, search_string);
        };
        input.attr('disabled', false);
      }
    };
  };

canto.directive('featureComplete',
                ['$timeout', 'CantoGlobals', featureComplete]);


var ontologyTermSelect =
  function () {
    return {
      scope: {
        annotationType: '=',
        termFoundCallback: '&',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/ontology_term_select.html',
      controller: function ($scope) {
        $scope.foundCallback = function (termId, termName, searchString, matchingSynonym) {
          if (!termId) {
            // ignore callback, user has cleared the input field
            return;
          }
          $scope.termFoundCallback({
            termId: termId,
            termName: termName,
            searchString: searchString,
            matchingSynonym: matchingSynonym,
          });
        };
      },
      link: function () {
        $('#loading').unbind('.canto');
        $('#ferret-term-input').attr('disabled', false);
      },
    };
  };

canto.directive('ontologyTermSelect', [ontologyTermSelect]);


var externalTermLinks =
  function (CantoService, CantoConfig) {
    return {
      scope: {
        termId: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/external_term_links.html',
      controller: function ($scope) {
        $scope.processExternalLinks = function (linkConfig, newTermId) {
          var link_confs = linkConfig[$scope.termDetails.annotation_namespace];
          if (link_confs) {
            var html = '';
            $.each(link_confs, function (idx, link_conf) {
              var url = link_conf.url;
              // hacky: allow a substitution like WebUtil::substitute_paths()
              var re = new RegExp("@@term_ont_id(?::s/(.+)/(.*)/r)?@@");
              url = url.replace(re,
                function (match_str, p1, p2) {
                  if (!p1 || p1.length == 0) {
                    return newTermId;
                  }
                  return newTermId.replace(new RegExp(p1), p2);
                });
              var img_src =
                application_root + '/static/images/logos/' +
                link_conf.icon;
              var title = 'View in: ' + link_conf.name;
              html += '<div class="curs-external-link"><a target="_blank" href="' +
                url + '" title="' + title + '">';
              if (img_src) {
                html += '<img alt="' + title + '" src="' + img_src + '"/></a>';
              } else {
                html += title;
              }
              var link_img_src = application_root + '/static/images/ext_link.png';
              html += '<img src="' + link_img_src + '"/></div>';
            });
            var $linkouts = $('.curs-term-linkouts');
            if (html.length > 0) {
              $linkouts.find('.curs-term-linkout-target').html(html);
              $linkouts.show();
            } else {
              $linkouts.hide();
            }
          }
        };

        $scope.$watch('termId',
          function (newTermId) {
            if (!newTermId) {
              return;
            }

            CantoService.lookup('ontology', [newTermId], {
                def: 1,
              })
              .then(function (data) {
                $scope.termDetails = data;

                return CantoConfig.get('ontology_external_links');
              })
              .then(function (data) {
                $scope.processExternalLinks(data, newTermId);
              });
          });

      },
    };
  };

canto.directive('externalTermLinks',
  ['CantoService', 'CantoConfig', externalTermLinks]);


var ontologyTermConfirm =
  function ($uibModal, toaster, CantoService, CantoConfig, CantoGlobals) {
    return {
      scope: {
        annotationType: '=',
        featureDisplayName: '@',
        termId: '@',
        matchingSynonym: '@',
        gotoChildCallback: '&',
        unsetTermCallback: '&',
        suggestTermCallback: '&',
        confirmTermCallback: '&',
        doNotAnnotateCurrentTerm: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/ontology_term_confirm.html',
      controller: function ($scope) {
        $scope.synonymTypes = [];

        $scope.$watch('annotationType.name',
          function (typeName) {
            if (typeName) {
              $scope.synonymTypes = $scope.annotationType.synonyms_to_display;
            }
          });

        $scope.app_static_path = CantoGlobals.app_static_path;

        $scope.checkDoNotAnnotate = function (configDoNotAnnotateSubsets) {
          $scope.doNotAnnotateCurrentTerm =
            arrayIntersection(configDoNotAnnotateSubsets,
              $scope.termDetails.subset_ids).length > 0;
        };

        $scope.$watch('termId',
          function (newTermId) {
            if (newTermId) {
              CantoService.lookup('ontology', [newTermId], {
                  def: 1,
                  children: 1,
                  synonyms: $scope.synonymTypes,
                  subset_ids: 1,
                })
                .then(function (data) {
                  $scope.termDetails = data;

                  $scope.doNotAnnotateCurrentTerm = false;

                  CantoConfig.get('ontology_namespace_config')
                    .then(function (data) {
                      $scope.ontology_namespace_config = data;
                      var doNotAnnotateSubsets =
                        data['do_not_annotate_subsets'] || [];

                      $scope.checkDoNotAnnotate(doNotAnnotateSubsets);
                    });
                });
            } else {
              $scope.termDetails = null;
            }
          });

        $scope.gotoChild = function (childId) {
          $scope.gotoChildCallback({
            childId: childId
          });
        };

        $scope.unsetTerm = function () {
          $scope.unsetTermCallback();
        };
        $scope.suggestTerm = function (termSuggestion) {
          $scope.suggestTermCallback({
            termSuggestion: termSuggestion
          });
        };
        $scope.confirmTerm = function () {
          $scope.confirmTermCallback();
        };

        $scope.openTermSuggestDialog =
          function (featureDisplayName) {
            var suggestInstance = $uibModal.open({
              templateUrl: app_static_path + 'ng_templates/term_suggest.html',
              controller: 'TermSuggestDialogCtrl',
              title: 'Suggest a new term for ' + featureDisplayName,
              animate: false,
              windowClass: "modal",
              backdrop: 'static',
            });

            suggestInstance.result.then(function (termSuggestion) {
              $scope.suggestTerm(termSuggestion);

              toaster.pop('note',
                'Your term suggestion will be stored, but ' +
                featureDisplayName + ' will be temporarily ' +
                'annotated with the parent of your suggested new term',
                null, 20000);
            });
          };
      },
    };
  };


canto.directive('ontologyTermConfirm',
  ['$uibModal', 'toaster', 'CantoService', 'CantoConfig', 'CantoGlobals',
    ontologyTermConfirm
  ]);


var ontologyTermCommentTransfer =
  function (CantoGlobals) {
    return {
      scope: {
        annotationType: '=',
        featureType: '@',
        featureDisplayName: '@',
        annotationDetails: '=',
        comment: '=',
        figOrTable: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/ontology_term_comment_transfer.html',
      controller: function ($scope) {
        $scope.showFigureField = CantoGlobals.annotationFigureField;
      },
   };
  };

canto.directive('ontologyTermCommentTransfer',
                ['CantoGlobals', ontologyTermCommentTransfer]);


function openExtensionRelationDialog($uibModal, extensionRelation, relationConfig) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/extension_relation_dialog.html',
    controller: 'ExtensionRelationDialogCtrl',
    title: 'Edit extension relation',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function () {
        return {
          extensionRelation: extensionRelation,
          relationConfig: relationConfig,
        };
      },
    },
    backdrop: 'static',
  }).result;
}

function arrayIntersection(arr1, arr2) {
  var intersect = [];

  $.map(arr1,
    function (el) {
      if ($.inArray(el, arr2) != -1) {
        intersect.push(el);
      }
    });

  return intersect;
}


// Filter the extension_configuration results from the server and return
// only those where the "domain" term ID in the configuration matches one of
// subsetIds.  Also ignore any configs where the "role" is "admin" and the
// current, logged in user isn't an admin.
function extensionConfFilter(allConfigs, subsetIds, userRole, annotationTypeName, featureType) {
  return allConfigs.filter(isValidExtension).map(getProperties);

  function getProperties(config) {
    return {
      displayText: config.display_text,
      relation: config.allowed_relation,
      domain: config.domain,
      role: config.role,
      range: config.range,
      rangeValue: null,
      cardinality: config.cardinality,
    };
  }

  function isValidExtension(config) {
    var userNotPermitted = (config.role == 'admin' && userRole != 'admin');
    var noAnnotationTypeMatch = (
      !! config.annotation_type_name &&
      config.annotation_type_name !== annotationTypeName
    );
    var wrongFeatureType = (
      !! featureType && !! config.feature_type &&
      config.feature_type != featureType
    );

    if (userNotPermitted || wrongFeatureType) {
      return false;
    }
    if (noAnnotationTypeMatch) {
      var found = false;
      var annotationTypeParts = config.annotation_type_name.split(/\|/);

      found = annotationTypeParts.some(function (part) {
        return part.match(/\w/) && annotationTypeName === part;
      });
      if (! found) {
        return false;
      }
    }
    var isSubsetIdMatch = config.subset_rel.some(function (subsetRelation) {
      var subsetId = subsetRelation + '(' + config.domain + ')';
      return subsetIds.indexOf(subsetId) !== -1;
    });
    if (! isSubsetIdMatch) {
      return false;
    }
    var isSubsetExcluded = (
      !! config.exclude_subset_ids &&
      arrayIntersection(config.exclude_subset_ids, subsetIds).length > 0
    );
    if (isSubsetExcluded) {
      return false;
    }
    return true;
  }
}


var extensionBuilderDialogCtrl =
  function ($scope, $uibModalInstance, args) {
    $scope.data = args;
    $scope.extensionBuilderIsValid = false;

    $scope.ok = function () {
      $uibModalInstance.close({
        extension: $scope.data.extension,
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('ExtensionBuilderDialogCtrl',
  ['$scope', '$uibModalInstance', 'args',
    extensionBuilderDialogCtrl
  ]);


function openExtensionBuilderDialog($uibModal, extension, termId, featureDisplayName, annotationTypeName, featureType) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/extension_builder_dialog.html',
    controller: 'ExtensionBuilderDialogCtrl',
    title: 'Edit extension',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function () {
        return {
          extension: angular.copy(extension),
          termId: termId,
          featureDisplayName: featureDisplayName,
          annotationTypeName: annotationTypeName,
          featureType: featureType,
        };
      },
    },
    backdrop: 'static',
  }).result;
}


function extensionAsString(extension, displayMode, hideRelation) {
  if (!extension) {
    return null;
  }

  return $.map(extension,
    function (orPart) {
      return $.map(orPart,
        function (andPart) {
          var retVal = '';

          if (!hideRelation) {
            retVal += andPart.relation + '(';
          }
          retVal += (displayMode ?
                     andPart.rangeDisplayName || andPart.rangeValue :
                     andPart.rangeValue);
          if (!hideRelation) {
            retVal += ')';
          }
          return retVal;
        }).join(', ');
    }).join('| ');
}

function parseExtensionAndPart(orPart) {
  orPart = orPart.trim();
  if (orPart.length == 0) {
    return {
      error: null,
      parsedPart: [],
    };
  }
  var split = orPart.split(/,/);
  var i, part, matchResult;
  var parsedPart = [];
  for (i = 0; i < split.length; i++) {
    part = split[i];
    matchResult = part.match(/^\s*(\S+?)\s*\(\s*([^)]+?)\s*\)/);
    if (matchResult && matchResult.length == 3) {
      parsedPart.push({
        relation: matchResult[1],
        rangeValue: matchResult[2],
        rangeDisplayName: matchResult[2],
      });
    } else {
      return {
        error: 'String "' + part + '" cannot be parsed',
        parsedPart: null,
      };
    }
  }

  return {
    error: null,
    parsedPart: parsedPart,
  };
}


function parseExtensionString(extensionString) {
  extensionString = extensionString.trim();
  if (extensionString.length == 0) {
    return {
      error: null,
      extension: [],
    };
  }
  var orParts = extensionString.split(/\|/);
  var i;
  var extension = [];
  for (i = 0; i < orParts.length; i++) {
    var result = parseExtensionAndPart(orParts[i]);

    if (result.error) {
      return result;
    }

    extension.push(result.parsedPart);
  }

  return {
    error: null,
    extension: extension,
  };
}

var extensionManualEditDialogCtrl =
  function ($scope, $uibModalInstance, CursGeneList, args) {
    $scope.currentError = "";
    $scope.genes = {};

    CursGeneList.geneList().then(function (results) {
      $.map(results,
            function(gene) {
              $scope.genes[gene.primary_identifier] = gene;
            });
    });

    $scope.editExtension =
      $.map(args.extension,
        function (part) {
          var newPart = {};
          copyObject(part, newPart);
          return newPart;
        });

    $scope.isValid = function () {
      return $scope.currentError.length == 0;
    };

    $scope.fixGenes = function() {
      if (Object.keys($scope.genes).length > 0) {
        return $.map($scope.editExtension,
                     function (orPart) {
                       return $.map(orPart,
                                    function (andPart) {
                                      var gene = $scope.genes[andPart.rangeValue];
                                      if (gene) {
                                        andPart.rangeDisplayName =
                                          gene.display_name || andPart.rangeValue;
                                      }
                                    });
                     });
      }
    };

    $scope.ok = function () {
      $scope.fixGenes();

      $uibModalInstance.close({
        extension: $scope.editExtension,
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('ExtensionManualEditDialogCtrl',
                 ['$scope', '$uibModalInstance', 'CursGeneList', 'args',
    extensionManualEditDialogCtrl
  ]);


function openExtensionManualEditDialog($uibModal, extension, matchingConfigurations) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/extension_manual_edit_dialog.html',
    controller: 'ExtensionManualEditDialogCtrl',
    title: 'Edit extension as text',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function () {
        return {
          extension: extension,
          matchingConfigurations: matchingConfigurations,
        };
      },
    },
    backdrop: 'static',
  }).result;
}


var extensionManualEdit =
  function () {
    return {
      scope: {
        extension: '=',
        currentError: '=',
        matchingConfigurations: '=',
      },
      restrict: 'E',
      replace: true,
      template: '<div> <textarea ng-model="text" rows="4" cols="65"></textarea> </div>',
      link: function ($scope) {
        $scope.currentError = "";
        $scope.text = extensionAsString($scope.extension, false, false);

        $scope.$watch('text',
          function () {
            var result = parseExtensionString($scope.text);

            if (result.error) {
              $scope.currentError = result.error;
            } else {
              $scope.currentError = "";
              $scope.extension = result.extension;
            }
          });
      },
    };
  };

canto.directive('extensionManualEdit',
  [extensionManualEdit]);


var extensionOrGroupBuilder =
  function ($uibModal, $q, CantoGlobals, CantoConfig, CantoService) {
    return {
      scope: {
        orGroup: '=',
        matchingConfigurations: '=',
        isValid: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_or_group_builder.html',
      controller: function ($scope) {
        $scope.isValid = true;
        $scope.currentUserIsAdmin = CantoGlobals.current_user_is_admin;
        $scope.manualEditMode = false;

        // the current counts of relations, used to test the cardinality
        // constraints
        $scope.cardinalityCounts = null;

        $scope.makeCountKey = function (extensionRelConf) {
          return extensionRelConf.relation + '-' +
            $.map(extensionRelConf.range,
              function (part) {
                var ret = part.type;
                if (part.type == 'Ontology') {
                  ret += '-' + part.scope.join(';');
                }
                return ret;
              }).join('|');
        };

        $scope.checkCardinality = function (matchingConfigurations) {
          var newCounts = {};
          var promises = [];

          $scope.cardinalityCounts = null;

          if (!matchingConfigurations) {
            return;
          }

          $.map(matchingConfigurations,
            function (relConf) {
              var incrementNewCounts =
                function () {
                  var key = $scope.makeCountKey(relConf);
                  if (newCounts[key]) {
                    newCounts[key]++;
                  } else {
                    newCounts[key] = 1;
                  }
                };
              $.map($scope.orGroup,
                function (part) {
                  var matchingRangeConf = {};
                  $.map(relConf.range,
                    function (rangeConf) {
                      if (rangeConf.type == part.rangeType) {
                        matchingRangeConf = rangeConf;
                      }
                    });

                  if (!matchingRangeConf) {
                    return;
                  }

                  if (part.relation == relConf.relation) {
                    if (matchingRangeConf.type == 'Ontology') {
                      var promise =
                        CantoService.lookup('ontology', [part.rangeValue], {
                          subset_ids: 1,
                        })
                        .then(function (data) {
                          var isInSubset = false;
                          data.subset_ids.filter(function (subset_id) {
                            if (matchingRangeConf.scope.indexOf(subset_id) != -1) {
                              isInSubset = true;
                            } else {
                              var matchResult = subset_id.match(/is_a\((.*)\)/);
                              if (matchResult) {
                                // check for subset_id without the "is_a(" too
                                if (matchingRangeConf.scope.indexOf(matchResult[1]) != -1) {
                                  isInSubset = true;
                                }
                              }
                            }
                          });
                          if (isInSubset) {
                            incrementNewCounts();
                          }
                        });

                      promises.push(promise);
                    } else {
                      incrementNewCounts();
                    }
                  }
                });
            });

          $q.all(promises).then(function () {
            $scope.cardinalityCounts = newCounts;
          });
        };

        $scope.getCardinalityCount = function (extensionRelConf) {
          if ($scope.cardinalityCounts) {
            return $scope.cardinalityCounts[$scope.makeCountKey(extensionRelConf)] || 0;
          }

          return 0;
        };

        $scope.getRemainingCardinality = function (extensionRelConf) {
          var count = $scope.getCardinalityCount(extensionRelConf);
          var cardinalityConf = extensionRelConf.cardinality;
          var i, cardinality;
          for (i = 0; i < cardinalityConf.length; i += 1) {
            cardinality = cardinalityConf[i];
            if (cardinality == '*') {
              return Infinity;
            }
            if (count < cardinality) {
              return cardinality - count;
            }
          }
          return 0;
        };

        $scope.cardinalityStatus = function (extensionRelConf) {
          var extensionCount = $scope.getCardinalityCount(extensionRelConf);
          var cardinalityConf = extensionRelConf.cardinality;
          var minCardinality = cardinalityConf[0];
          if (minCardinality == 0) {
            if (cardinalityConf.length === 1) {
              return 'MAX_REACHED';
            }
            if (extensionCount == 0) {
              return 'OPTIONAL';
            }
          }
          var i, cardinality, isLastCardinality;
          for (i = 0; i < cardinalityConf.length; i += 1) {
            cardinality = cardinalityConf[i];
            if (cardinality == '*') {
              return 'OPTIONAL';
            }
            isLastCardinality = (i === cardinalityConf.length - 1);
            if (extensionCount == cardinality) {
              if (isLastCardinality) {
                return 'MAX_REACHED';
              }
              if (cardinalityConf[i + 1] == '*') {
                return 'OPTIONAL'
              }
              return 'MORE_AVAILABLE';
            }
            if (extensionCount < cardinality) {
              return 'MORE_REQUIRED';
            }
          }
          return 'OPTIONAL';
        };

        $scope.setIsValid = function () {
          $scope.isValid = true;

          if ($scope.matchingConfigurations) {
            $.map($scope.matchingConfigurations,
              function (relConf) {
                if ($scope.cardinalityStatus(relConf) == 'MORE_REQUIRED') {
                  $scope.isValid = false;
                }
              });
          }
        };

        $scope.$watch('orGroup',
          function () {
            $scope.checkCardinality($scope.matchingConfigurations);
          }, true);

        $scope.$watch('matchingConfigurations',
          function () {
            $scope.checkCardinality($scope.matchingConfigurations);
          }, true);

        $scope.$watch('cardinalityCounts',
          function () {
            $scope.setIsValid();
          }, true);

        $scope.startAddRelation = function (relationConfig) {
          var editExtensionRelation = {
            relation: relationConfig.relation,
            rangeDisplayName: '',
          };

          var editPromise =
            openExtensionRelationDialog($uibModal, editExtensionRelation, relationConfig);

          editPromise.then(function (result) {
            $scope.orGroup.push(result.extensionRelation);
          });
        };
      },
    };
  };

canto.directive('extensionOrGroupBuilder',
  ['$uibModal', '$q', 'CantoGlobals', 'CantoConfig', 'CantoService',
    extensionOrGroupBuilder
  ]);

function extensionIsEmpty(extension) {
  if (extension) {
    if (extension.length == 0 ||
      extension.length == 1 && extension[0].length == 0) {
      return false;
    }

    return true;
  }

  return false;
}

var extensionBuilder =
  function ($uibModal, $q, CantoGlobals, CantoConfig, CantoService) {
    return {
      scope: {
        extension: '=',
        termId: '@',
        featureDisplayName: '@',
        isValid: '=',
        annotationTypeName: '@',
        featureType: '<',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_builder.html',
      controller: function ($scope) {
        $scope.isValid = true;
        $scope.currentUserIsAdmin = CantoGlobals.current_user_is_admin;
        $scope.manualEditMode = false;
        $scope.matchingConfigurations = [];

        if (!$scope.extension || $scope.extension.length == 0) {
          $scope.extension = [
            []
          ];
        }

        $scope.isNewExtension = extensionIsEmpty($scope.extension);

        $scope.extensionConfiguration = [];
        $scope.termDetails = {
          id: null
        };

        $scope.updateMatchingConfig = function () {
          var subset_ids = $scope.termDetails.subset_ids;

          if ($scope.extensionConfiguration.length > 0 &&
            subset_ids && subset_ids.length > 0) {
            var newConf =
              extensionConfFilter(
                $scope.extensionConfiguration,
                subset_ids,
                CantoGlobals.current_user_is_admin ? 'admin' : 'user',
                $scope.annotationTypeName,
                $scope.featureType
              );
            copyObject(newConf, $scope.matchingConfigurations);
            return;
          }

          $scope.matchingConfigurations = [];
        };

        $scope.$watch('termId',
          function (newTermId) {
            if (newTermId) {
              CantoService.lookup('ontology', [newTermId], {
                  subset_ids: 1,
                })
                .then(function (data) {
                  $scope.termDetails = data;
                  CantoConfig.get('extension_configuration')
                    .then(function (data) {
                      $scope.extensionConfiguration = data;
                      $scope.updateMatchingConfig();
                    });
                });
              return;
            }
            $scope.termDetails = {
              id: null
            };
          });

        $scope.addOrGroup = function () {
          if ($scope.extension[$scope.extension.length - 1].length != 0) {
            $scope.extension.push([]);
          }
        };

        $scope.manualEdit = function () {
          var editPromise =
            openExtensionManualEditDialog($uibModal, $scope.extension, $scope.matchingConfigurations);

          editPromise.then(function (result) {
            $scope.extension = result.extension;
          });
        };

        $scope.debugConfText = function (conf) {
          if ($scope.currentUserIsAdmin) {
            return "domain: " + conf.domain + "\nrole: " + conf.role +
              "\nrange: " + JSON.stringify(conf.range, null, 2);
          } else {
            return "";
          }
        };
      },
    };
  };

canto.directive('extensionBuilder',
  ['$uibModal', '$q', 'CantoGlobals', 'CantoConfig', 'CantoService',
    extensionBuilder
  ]);


var extensionRelationDialogCtrl =
  function ($scope, $uibModalInstance, args, CursGeneList, toaster) {
    $scope.data = args;
    $scope.extensionRelation = args.extensionRelation;
    $scope.relationConfig = args.relationConfig;
    $scope.selected = {
      rangeType: $scope.relationConfig.range[0].type,
    };
    $scope.extensionRelation.rangeType = $scope.selected.rangeType;

    $scope.isValid = function () {
      return !!$scope.data.extensionRelation.rangeValue;
    };

    $scope.okTitle = function () {
      if ($scope.isValid()) {
        return "Add extension";
      } else {
        return "Make a selection to continue";
      }
    };

    $scope.$watch('selected',
      function () {
        $scope.extensionRelation.rangeType = $scope.selected.rangeType;
      }, true);

    CursGeneList.geneList().then(function (results) {
      $scope.genes = results;
    }).catch(function (err) {
      toaster.pop('note', "couldn't read the gene list from the server");
    });

    $scope.ok = function () {
      if ($scope.extensionRelation.rangeType == '%') {
        $scope.extensionRelation.rangeValue =
          $scope.extensionRelation.rangeValue.replace(/%\s*$/, '');
      }
      $uibModalInstance.close({
        extensionRelation: $scope.extensionRelation,
      });
    };

    $scope.finishedCallback = function () {
      $scope.ok();
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('ExtensionRelationDialogCtrl',
  ['$scope', '$uibModalInstance', 'args', 'CursGeneList', 'toaster',
    extensionRelationDialogCtrl
  ]);

function openTermConfirmDialog($uibModal, termId, initialState, featureType, isExtensionTerm) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/term_confirm.html',
    controller: 'TermConfirmDialogCtrl',
    title: 'Confirm term',
    animate: false,
    windowClass: "modal",
    size: 'lg',
    resolve: {
      args: function () {
        return {
          termId: termId,
          initialState: initialState,
          featureType: featureType,
          isExtensionTerm: isExtensionTerm,
        };
      }
    },
    backdrop: 'static',
  });
}


var extensionRelationEdit =
  function (CantoService, Curs, CursGeneList, toaster, $uibModal) {
    return {
      scope: {
        extensionRelation: '=',
        relationConfig: '=',
        rangeConfig: '=',
        disabled: '=',
        finishedCallback: '&',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_relation_edit.html',
      controller: function ($scope) {
        $scope.rangeGeneId = '';
        $scope.rangeMetagenotypeUniquename = '';

        $scope.genes = null;
        $scope.metagenotypes = null;
        $scope.organisms = null;

        $scope.getGenesFromServer = function() {
          return CursGeneList.geneList().then(function (results) {
            $scope.genes = results;
          }).catch(function () {
            toaster.pop('note', "couldn't read the gene list from the server");
          });
        };

        $scope.getGenesFromServer();

        $scope.getMetagenotypesFromServer = function() {
          Curs.list('metagenotype').then(function (results) {
            $scope.metagenotypes = results;
          }).catch(function () {
            toaster.pop('note', "couldn't read the metagenotype list from the server");
          });
        };

        $scope.getOrganismsFromServer = function () {
          Curs.list('organism').then(function (organisms) {
            var rangeType = $scope.extensionRelation.rangeType;
            if (rangeType === 'PathogenTaxonID') {
              $scope.organisms = filterOrganisms(organisms, 'pathogen');
            } else if (rangeType === 'HostTaxonID') {
              $scope.organisms = filterOrganisms(organisms, 'host');
            } else {
              $scope.organisms = organisms;
            }
          }).catch(function () {
            toaster.pop('note', "couldn't read the organism list from the server");
          });
        };

        $scope.getMetagenotypesFromServer();

        if ($scope.extensionRelation.rangeType.indexOf('TaxonID') !== -1) {
          $scope.getOrganismsFromServer();
        }

        $scope.openSingleGeneAddDialog = function () {
          var modal = openSingleGeneAddDialog($uibModal);
          modal.result.then(function (results) {
            var newGeneId = results.new_gene_id;
            $scope.getGenesFromServer()
              .then(function() {
                $.map($scope.genes,
                      function(gene) {
                        if (gene.feature_id == newGeneId) {
                          $scope.extensionRelation.rangeValue = gene.primary_identifier;
                          $scope.extensionRelation.rangeDisplayName = gene.display_name;
                          $scope.rangeGeneId = gene.feature_id;
                        }
                      });
              });
          });
        };

        $scope.disableAll = function (element, disabled) {
          $(element).find('input').attr('disabled', disabled);
          $(element).find('select').attr('disabled', disabled);
        };

        $scope.organismSelected = function (organism) {
          $scope.extensionRelation.rangeValue = organism.taxonid;
          $scope.extensionRelation.rangeDisplayName = organism.scientific_name;
        };

        $scope.termFoundCallback = function (termId, termName, searchString) {
          if (!termId) {
            // ignore callback, user has cleared the input field
            return;
          }

          $scope.extensionRelation.rangeValue = termId;
          $scope.extensionRelation.rangeDisplayName = termName;

          if (searchString && !searchString.match(/^".*"$/) && searchString !== termId) {
            var termConfirm =
              openTermConfirmDialog($uibModal, termId, null, null, true);

            termConfirm.result.then(function (result) {
              $scope.extensionRelation.rangeValue = result.newTermId;
              $scope.extensionRelation.rangeDisplayName = result.newTermName;
              $scope.finishedCallback();
            });
          } // else: user pasted a term ID or user quoted the search - skip confirmation
        };

        if ($scope.rangeConfig.type == 'Gene') {
          if (!$scope.extensionRelation.rangeValue) {
            $scope.extensionRelation.rangeValue = '';
          }
        }

        if ($scope.rangeConfig.type == 'Ontology') {
          var rangeScope = $scope.rangeConfig.scope;
          $scope.rangeOntologyScope =
            makeRangeScopeForRequest(rangeScope);

          if ($scope.extensionRelation.rangeValue) {
            // editing existing extension part
            CantoService.lookup('ontology', [$scope.extensionRelation.rangeValue], {})
              .then(function (data) {
                $scope.extensionRelation.rangeDisplayName = data.name;
              });
          }
        }

        $scope.valueIsValid = function () {
          if ($scope.rangeConfig.type == '%') {
            return $scope.percentParseMessage().length == 0;
          } else {
            return true;
          }
        };

        $scope.percentParseMessage = function () {
          if ($scope.disabled) {
            return '';
          }

          if ($scope.rangeConfig.type == '%') {
            var rangeValue = $scope.extensionRelation.rangeValue;

            if (typeof (rangeValue) == 'undefined' || trim(rangeValue).length == 0) {
              return "Required";
            }

            var re = new RegExp(/^\s*(\d+|\d+\.\d*|\d*\.\d+)(?:-(\d+|\d+\.\d*|\d*\.\d+))?\s*%?$/);
            var result = re.exec($scope.extensionRelation.rangeValue);

            if (result) {
              var pcStart = Number(result[1]);

              if (pcStart > 100) {
                return 'Value must be <= 100';
              }

              if (result.length > 2) {
                var pcEnd = result[2];
                if (+pcEnd < +pcStart) {
                  return "start of range greater than end: " +
                    pcStart + ">" + pcEnd;
                }

                return '';
              }
            } else {
              return 'Value must be a percentage, e.g. 45%';
            }
          } else {
            return '';
          }
        };
      },
      link: function ($scope, elem) {
        $scope.$watch('disabled',
          function () {
            $scope.disableAll(elem, $scope.disabled);
            $scope.extensionRelation.rangeValue = '';
          }
        );
      }
    };
  };

canto.directive('extensionRelationEdit',
                ['CantoService', 'Curs', 'CursGeneList', 'toaster', '$uibModal',
    extensionRelationEdit
  ]);


var extensionDisplay =
  function (CantoGlobals) {
    return {
      scope: {
        extension: '=',
        showDelete: '@',
        hideRelationNames: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_display.html',
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
      },
    };
  };

canto.directive('extensionDisplay', ['CantoGlobals', extensionDisplay]);


var extensionOrGroupDisplay =
  function (CantoGlobals, CantoService) {
    return {
      scope: {
        extension: '=',
        orGroup: '=',
        showDelete: '@',
        editable: '@',
        isFirst: '@',
        hideRelationNames: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_or_group_display.html',
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;

        $.map($scope.orGroup,
          function (andGroup) {
            if (!andGroup.rangeDisplayName &&
                (!andGroup.rangeType && andGroup.rangeValue.match('^[A-Z_]+:\\d+') ||
                 andGroup.rangeType && andGroup.rangeType == 'Ontology')) {
              CantoService.lookup('ontology', [andGroup.rangeValue], {})
                .then(function (data) {
                  andGroup.rangeDisplayName = data.name;
                });
            }
          });

        $scope.isHiddenRelName = function (relName) {
          if (!$scope.hideRelationNames) {
            return false;
          }
          return $.grep($scope.hideRelationNames,
                        function(hideRelName) {
                          return hideRelName == relName;
                        }).length > 0;
        };

        $scope.deleteAndGroup = function (andGroup) {
          if ($scope.showDelete) {
            arrayRemoveOne($scope.orGroup, andGroup);
            if ($scope.orGroup.length == 0 && $scope.extension.length > 1) {
              arrayRemoveOne($scope.extension, $scope.orGroup);
            }
          }
        };
      },
    };
  };

canto.directive('extensionOrGroupDisplay',
  ['CantoGlobals', 'CantoService', extensionOrGroupDisplay]);


var ontologyWorkflowCtrl =
  function ($scope, toaster, $http, CantoGlobals, AnnotationTypeConfig, CantoService,
    CantoConfig, CursGeneList, CursGenotypeList, CursStateService, $attrs) {
    $scope.states = ['searching', 'selectingEvidence', 'buildExtension', 'commenting'];

    CursStateService.setState($scope.states[0]);
    $scope.annotationForServer = null;
    $scope.data = CursStateService;
    $scope.annotationTypeName = $attrs.annotationTypeName;
    $scope.finalFeatureType = $attrs.featureType;

    $scope.extensionBuilderReady = false;
    $scope.matchingExtensionConfigs = null;

    $scope.extensionBuilderIsValid = true;

    $scope.doNotAnnotateCurrentTerm = false;

    $scope.storeInProgress = false;

    $scope.updateMatchingConfig = function () {
      var subsetIds = $scope.termDetails.subset_ids;
      var matchingExtensionConfigs = [];

      if (subsetIds && subsetIds.length > 0) {
        matchingExtensionConfigs = extensionConfFilter(
          $scope.extensionConfiguration,
          subsetIds,
          CantoGlobals.current_user_is_admin ? 'admin' : 'user',
          $scope.annotationTypeName,
          $scope.finalFeatureType
        );
      }

      $scope.matchingExtensionConfigs = matchingExtensionConfigs;
    };

    $scope.termFoundCallback =
      function (termId, termName, searchString, matchingSynonym) {
        if (!termId) {
          // ignore callback, user has cleared the input field
          return;
        }

        CursStateService.clearTerm();
        CursStateService.addTerm(termId);
        CursStateService.searchString = searchString;
        CursStateService.matchingSynonym = matchingSynonym;

        $scope.matchingExtensionConfigs = null;

        CantoService.lookup('ontology', [termId], {
            subset_ids: 1,
          })
          .then(function (data) {
            $scope.termDetails = data;
            if (!$scope.termDetails.annotation_type_name) {
              $scope.termDetails.annotation_type_name = $scope.annotationTypeName;
            }
            CantoConfig.get('extension_configuration')
              .then(function (data) {
                $scope.extensionConfiguration = data;
                $scope.updateMatchingConfig();
              });
          });
      };

    $scope.gotoChild = function (termId) {
      CursStateService.addTerm(termId);
    };

    $scope.matchingSynonym = function () {
      return CursStateService.matchingSynonym;
    };

    $scope.getState = function () {
      return CursStateService.getState();
    };

    $scope.suggestTerm = function (suggestion) {
      CursStateService.termSuggestion = suggestion;

      $scope.gotoNextState();
    };

    $scope.gotoPrevState = function () {
      CursStateService.setState($scope.prevState());
    };

    $scope.gotoNextState = function () {
      CursStateService.setState($scope.nextState());
    };

    $scope.back = function () {
      if ($scope.getState() == 'searching') {
        CursStateService.clearTerm();
        $scope.extensionBuilderReady = false;
        return;
      }

      if ($scope.getState() == 'commenting') {
        if ($scope.matchingExtensionConfigs &&
          $scope.matchingExtensionConfigs.length == 0) {
          var evidenceIsAllowedState =
              $.grep($scope.states, function(state) {
                return state === 'selectingEvidence';
              }).length > 0;
          if (evidenceIsAllowedState) {
            CursStateService.setState('selectingEvidence');
          } else {
            CursStateService.setState('searching');
          }
          return;
        }
      }

      $scope.gotoPrevState();
    };

    $scope.proceed = function () {
      if ($scope.getState() == 'commenting') {
        $scope.storeInProgress = true;
        $scope.storeAnnotation();
        return;
      }

      if ($scope.getState() == 'selectingEvidence') {
        if ($scope.matchingExtensionConfigs &&
          $scope.matchingExtensionConfigs.length == 0) {
          CursStateService.setState('commenting');
          return;
        }
      }

      $scope.gotoNextState();
    };

    $scope.prevState = function () {
      var index = $scope.states.indexOf($scope.getState());

      if (index <= 0) {
        return null;
      }

      return $scope.states[index - 1];
    };

    $scope.nextState = function () {
      var index = $scope.states.indexOf($scope.getState());

      if (index == $scope.states.length - 1) {
        return null;
      }

      return $scope.states[index + 1];
    };

    $scope.$watch('getState()',
      function (newState, oldState) {
        if (newState == 'commenting') {
          $scope.annotationForServer =
            CursStateService.asAnnotationDetails();
        } else {
          $scope.annotationForServer = {};
        }
      });

    $scope.currentTerm = function () {
      return CursStateService.currentTerm();
    };

    $scope.isValid = function () {
      if ($scope.getState() == 'searching' && $scope.doNotAnnotateCurrentTerm) {
        return false;
      }

      if ($scope.getState() == 'selectingEvidence') {
        if ($scope.matchingExtensionConfigs == null) {
          return false;
        }
        return $scope.data.validEvidence;
      }

      if ($scope.getState() == 'buildExtension' &&
        !$scope.extensionBuilderIsValid) {
        return false;
      }

      return true;
    };

    $scope.showConditions = function () {
      return $scope.data.validEvidence &&
        $scope.annotationType && $scope.annotationType.can_have_conditions;
    };

    $scope.storeAnnotation = function () {
      var storePop = toaster.pop({
        type: 'info',
        title: 'Storing annotation...',
        timeout: 0, // last until page reload
        showCloseButton: false
      });

      var promise =
        simpleHttpPost(toaster, $http,
          CantoGlobals.curs_root_uri + '/feature/' +
          $scope.annotationType.feature_type + '/annotate/' +
          $attrs.featureId + '/set_term/' + $scope.annotationType.name,
          CursStateService.asAnnotationDetails());

      promise.finally(function () {
        toaster.clear(storePop);
      });
    };

    function getOrganismMode(genotype, pathogenHostMode) {
      if (genotype !== null && pathogenHostMode) {
        return genotype.organism.pathogen_or_host;
      }
      return 'normal';
    }

    AnnotationTypeConfig
      .getByName($scope.annotationTypeName)
      .then(function (annotationType) {
        var featureType = annotationType.feature_type;
        var featureId = $attrs.featureId;
        var backToFeatureUrl = (
          CantoGlobals.curs_root_uri +
          '/feature/' + featureType +
          '/view/' + featureId
        );

        if (annotationType.evidence_codes.length === 0) {
          // skip the evidence selection state if there are no evidence codes
          $scope.states = ['searching', 'buildExtension', 'commenting'];
        }

        if (featureType == 'genotype') {
          CursGenotypeList
            .getGenotypeById(Number(featureId))
            .then(function (genotype) {
              var organismMode = getOrganismMode(
                genotype,
                CantoGlobals.pathogen_host_mode
              );
              backToFeatureUrl = (
                CantoGlobals.curs_root_uri +
                '/' + getGenotypeManagePath(organismMode) +
                '#/select/' + featureId
              );
            });
        } else if (featureType == 'gene' && CantoGlobals.pathogen_host_mode) {
          CursGeneList
            .getGeneById(Number(featureId))
            .then(function (gene) {
              var organismRole = gene.organism.pathogen_or_host;
              $scope.finalFeatureType = organismRole + '_gene';
            });
        }

        $scope.annotationType = annotationType;
        $scope.backToFeatureUrl = backToFeatureUrl;
      });
  };

canto.controller('OntologyWorkflowCtrl',
  ['$scope', 'toaster', '$http', 'CantoGlobals',
    'AnnotationTypeConfig', 'CantoService',
    'CantoConfig', 'CursGeneList', 'CursGenotypeList', 'CursStateService', '$attrs',
    ontologyWorkflowCtrl
  ]);


var interactionWorkflowCtrl =
  function ($scope, $http, toaster, $attrs) {

    $scope.annotationTypeName = $attrs.annotationTypeName;

    $scope.data = {
      validEvidence: false,
      evidenceConfirmed: false,
    };

    $scope.selectedFeatureIds = [];

    $scope.someFeaturesSelected = function () {
      return $scope.selectedFeatureIds.length > 0;
    };

    $scope.confirmEvidence = function () {
      $scope.data.evidenceConfirmed = true;
    };

    $scope.unconfirmEvidence = function () {
      $scope.data.evidenceConfirmed = false;
    };

    $scope.isValidEvidence = function () {
      return $scope.data.validEvidence;
    };

    $scope.backToGene = function () {
      history.go(-1);
    };

    $scope.addInteractionAndEvidence = function () {
      $scope.postInProgress = true;
      toaster.pop('info', 'Creating interaction...');
      simpleHttpPost(toaster, $http, '../add_interaction/' + $scope.annotationTypeName, {
        evidence_code: $scope.data.evidence_code,
        prey_gene_ids: $scope.selectedFeatureIds,
      });
    };
  };

canto.controller('InteractionWorkflowCtrl',
  ['$scope', '$http', 'toaster', '$attrs',
    interactionWorkflowCtrl
  ]);


var annotationEvidence =
  function (AnnotationTypeConfig, CantoConfig, CursGeneList, CantoService, $uibModal, toaster) {
    var directive = {
      scope: {
        evidenceCode: '=',
        withGeneId: '=',
        validEvidence: '=', // true when evidence and with_gene_id are valid
        annotationTypeName: '@',
        annotationTermOntid: '@',
      },
      restrict: 'E',
      replace: true,
      controller: function ($scope, $element, $attrs) {
        $scope.annotationType = null;
        $scope.defaultEvidenceCodes = [];
        $scope.evidenceCodes = [];

        $scope.genes = null;

        $scope.annotationTermData = null;

        $scope.getGenesFromServer = function() {
          CursGeneList.geneList().then(function (results) {
            $scope.genes = results;
          }).catch(function (err) {
            toaster.pop('note', "couldn't read the gene list from the server");
          });
        };

        $scope.getGenesFromServer();

        $scope.openSingleGeneAddDialog = function () {
          var modal = openSingleGeneAddDialog($uibModal);
          modal.result.then(function () {
            $scope.getGenesFromServer();
          });
        };

        AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function (annotationType) {
            $scope.annotationType = annotationType;
            $scope.defaultEvidenceCodes = annotationType.evidence_codes;
            $scope.evidenceCodes = annotationType.evidence_codes;
          });

        $scope.isValidEvidenceCode = function () {
          return $scope.evidenceCode && $scope.evidenceCode.length > 0 &&
            typeof ($scope.evidenceTypes) != 'undefined' &&
            $scope.evidenceTypes[$scope.evidenceCode];
        };

        $scope.isValidWithGene = function () {
          return $scope.evidenceTypes && $scope.evidenceCode &&
            ($scope.evidenceTypes[$scope.evidenceCode] &&
              !$scope.evidenceTypes[$scope.evidenceCode].with_gene ||
              $scope.withGeneId);
        };

        $scope.showWith = function () {
          return $scope.evidenceTypes && $scope.isValidEvidenceCode() &&
            $scope.evidenceTypes[$scope.evidenceCode].with_gene;
        };

        $scope.isValidCodeAndWith = function () {
          return $scope.isValidEvidenceCode() && $scope.isValidWithGene();
        };

        $scope.validEvidence = $scope.isValidCodeAndWith();

        $scope.getDisplayCode = function (code) {
          if ($scope.evidenceTypes) {
            var name = $scope.evidenceTypes[code].name;
            if (name) {
              if (name.startsWith(code)) {
                return name;
              }
              return name + ' (' + code + ')';
            }
          }

          return code;
        };

        $scope.getDefinition = function (code) {
          if ($scope.evidenceTypes) {
            var def = $scope.evidenceTypes[code].definition;
            if (def) {
              return def;
            }
          }

          return $scope.getDisplayCode(code);
        };

        CantoConfig.get('evidence_types').then(function (results) {
          $scope.evidenceTypes = results;

          $scope.$watch('evidenceCode',
            function () {
              if (!$scope.isValidEvidenceCode() ||
                !$scope.evidenceTypes[$scope.evidenceCode].with_gene) {
                $scope.withGeneId = undefined;
              }

              $scope.validEvidence = $scope.isValidCodeAndWith();
            });

          $scope.validEvidence = $scope.isValidCodeAndWith();
        });

        $scope.$watch('withGeneId',
          function () {
            $scope.validEvidence = $scope.isValidCodeAndWith();
          });

        function setTermEvidence(termData) {
          var termEvCodes = [];
          var subsetIds = termData.subset_ids;

          /** @type {Array<string>} */
          var newEvidenceCodes = null;

          function checkForRelAndTerm(relAndTerm) {
            return $.inArray(relAndTerm, subsetIds) != -1;
          }

          $.map(
            $scope.annotationType.term_evidence_codes,
            function(evConfig) {
              var evConfigConstraint = evConfig.constraint;
              var evConfigCodes = evConfig.evidence_codes;

              if (newEvidenceCodes != null) {
                return;
              }

              var includedRelAndTerm = null;
              var excludedRelAndTerms = [];

              if (evConfigConstraint.indexOf("-") == -1) {
                includedRelAndTerm = evConfigConstraint;
              } else {
                var parts = evConfigConstraint.split("-", 2);
                includedRelAndTerm = parts[0];
                excludedRelAndTerms = parts[1].split(/[\-&]/);
              }

              if (
                checkForRelAndTerm(includedRelAndTerm) &&
                $.grep(excludedRelAndTerms, checkForRelAndTerm).length == 0
              ) {
                newEvidenceCodes = evConfigCodes;
              }
            }
          );

          if (newEvidenceCodes) {
            newEvidenceCodes.sort();
            $scope.evidenceCodes = newEvidenceCodes;
          } else {
            $scope.evidenceCodes = $scope.defaultEvidenceCodes;
          }
        }

        $scope.$watch('annotationTermOntid',
          function (annotationTermOntid) {
            $scope.evidenceCodes = $scope.defaultEvidenceCodes;

            if (annotationTermOntid && $scope.annotationType &&
                $scope.annotationType.term_evidence_codes) {
              $scope.annotationTermData = null;
              CantoService.lookup('ontology', [annotationTermOntid],
                                  {
                                    subset_ids: 1,
                                  })
                .then(function (termData) {
                  $scope.annotationTermData = termData;
                  setTermEvidence(termData);
                });
            }
          });
      },
      templateUrl: app_static_path + 'ng_templates/annotation_evidence.html'
    };
    return directive;
  };

canto.directive('annotationEvidence',
                ['AnnotationTypeConfig', 'CantoConfig', 'CursGeneList', 'CantoService',
                 '$uibModal', 'toaster',
                 annotationEvidence]);

var conditionPicker =
  function (CursConditionList, toaster, CantoConfig) {
    var directive = {
      scope: {
        conditions: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function ($scope) {
        $scope.usedConditions = [];
        $scope.addCondition = function (condName) {
          // this hack stop apply() being called twice when user clicks an add
          // button
          setTimeout(function () {
            $scope.tagitList.tagit("createTag", condName);
          }, 1);
        };
      },
      templateUrl: app_static_path + 'ng_templates/condition_picker.html',
      link: function ($scope, elem) {
        var $field = elem.find('.curs-allele-conditions');

        if (typeof ($scope.conditions) != 'undefined') {
          CursConditionList.conditionList().then(function (results) {
            $scope.usedConditions = results;

            var updateScopeConditions = function () {
              // apply() is needed so the scope is update when a tag is added in
              // the Tagit field
              $scope.$apply(function () {
                $scope.conditions.length = 0;
                $field.find('li .tagit-label').map(function (index, $elem) {
                  $scope.conditions.push({
// This fix is a hacky work around for a bug in the tag-it library.
// If condition synonym is selected with down arrow + return, the
// synonym text is used as the condition instead of the term name.  So
// we remove the synonym text (the bit in brackets), leaving the term
// name.
                    name: $elem.textContent.trim().replace(/\s+\(.*\)$/, ''),
                  });
                });
              });
            };

            var conditionsNamespacePromise = CantoConfig.get('phenotype_condition_namespace');

            conditionsNamespacePromise.then(function (data) {
              var conditionsNamespace = data.value;
              $field.tagit({
                minLength: 2,
                fieldName: 'curs-allele-condition-names',
                allowSpaces: true,
                placeholderText: 'Start typing to add a condition',
                tagSource: fetch_conditions(conditionsNamespace),
                autocomplete: {
                  focus: ferret_choose.show_autocomplete_def,
                  close: ferret_choose.hide_autocomplete_def,
                },
              });
              $.map($scope.conditions,
                function (cond) {
                  $field.tagit("createTag", cond.name);
                });

              // don't start updating until all initial tags are added
              $field.tagit({
                afterTagAdded: updateScopeConditions,
                afterTagRemoved: updateScopeConditions,
              });

              $scope.tagitList = $field;
            }).catch(function () {
              toaster.pop('error', "couldn't read the conditions ontology namespace from the server");
            });

          }).catch(function () {
            toaster.pop('error', "couldn't read the condition list from the server");
          });
        }
      }
    };

    return directive;
  };

canto.directive('conditionPicker', ['CursConditionList', 'toaster', 'CantoConfig', conditionPicker]);

var alleleNameComplete =
  function (CursAlleleList, toaster) {
    var directive = {
      scope: {
        alleleName: '=',
        nameSelected: '&',
        geneIdentifier: '@',
        placeholder: '@'
      },
      restrict: 'E',
      replace: true,
      template: '<span><input ng-model="alleleName" placeholder="{{placeholder}}" type="text" class="curs-allele-name aform-control" value=""/></span>',
      controller: function ($scope) {
        $scope.allelePrimaryIdentifier = null;
        $scope.alleleSynonyms = null;
        $scope.alleleDescription = null;
        $scope.alleleType = null;

        $scope.clicked = function () {
          $scope.merge = $scope.alleleDescription + ' ' + $scope.allelePrimaryIdentifier;
        };
      },
      link: function (scope, elem) {
        var processResponse = function (lookupResponse) {
          return $.map(
            lookupResponse,
            function (el) {
              const synonyms = [];
              const seenSynonyms = {};

              if (el.synonyms) {
                el.synonyms.map(syn => {
                  const key = syn.synonym + '-' + syn.edit_status;
                  if (!seenSynonyms[key]) {
                    seenSynonyms[key] = true;
                    synonyms.push(syn);
                  }
                });
              }

              return {
                value: el.name,
                allele_primary_identifier: el.uniquename,
                display_name: el.display_name,
                description: el.description,
                synonyms: synonyms,
                type: el.type,
              };
            });
        };
        elem.find('input').autocomplete({
          source: function (request, response) {
            CursAlleleList.alleleNameComplete(scope.geneIdentifier, request.term)
              .then(function (lookupResponse) {
                response(processResponse(lookupResponse));
              })
              .catch(function () {
                toaster.pop("failed to lookup allele of: " + scope.geneName);
              });
          },
          select: function (event, ui) {
            scope.$apply(function () {
              if (typeof (ui.item.allele_primary_identifier) === 'undefined') {
                scope.allelePrimaryIdentifier = '';
              } else {
                scope.allelePrimaryIdentifier = ui.item.allele_primary_identifier;
              }
              scope.alleleType = ui.item.type;
              if (typeof (ui.item.label) === 'undefined') {
                scope.alleleName = '';
              } else {
                scope.alleleName = ui.item.label;
              }
              if (typeof (ui.item.description) === 'undefined') {
                scope.alleleDescription = '';
              } else {
                scope.alleleDescription = ui.item.description;
              }
              scope.alleleSynonyms = ui.item.synonyms;

              scope.nameSelected({
                alleleData: {
                  primaryIdentifier: scope.allelePrimaryIdentifier,
                  name: scope.alleleName,
                  synonyms: scope.alleleSynonyms,
                  description: scope.alleleDescription,
                  type: scope.alleleType,
                },
              });
            });
          }
        }).data("autocomplete")._renderItem = function (ul, item) {
          var inputValue = elem.find('input').val().trim().toLowerCase();
          var displayName = item.display_name;
          if (displayName.indexOf(inputValue) == -1) {
            if (item.synonyms) {
              SYN:
              for (var i = 0; i < item.synonyms.length; i++) {
                var syn = item.synonyms[i];
                if (syn.edit_status === 'existing' &&
                    syn.synonym.toLowerCase().indexOf(inputValue) != -1) {
                  displayName += ' (matching synonym: ' + syn.synonym  + ')';
                  break SYN;
                }
              }
            }
          }

          return $("<li></li>")
            .data("item.autocomplete", item)
            .append("<a>" + displayName + "</a>")
            .appendTo(ul);
        };
      }
    };

    return directive;
  };

canto.directive('alleleNameComplete', ['CursAlleleList', 'toaster', alleleNameComplete]);


function makeAutopopulateName(template, geneName) {
  return template.replace(/@@gene_display_name@@/, geneName);
}


var alleleEditDialogCtrl =
  function ($scope, $uibModal, $uibModalInstance, toaster, CantoConfig, args, Curs, CursGeneList, CantoGlobals) {
    $scope.alleleData = {};
    copyObject(args.allele, $scope.alleleData);
    $scope.taxonId = args.taxonId;
    $scope.isCopied = args.isCopied;
    $scope.lockedAlleleType = args.lockedAlleleType;
    $scope.alleleData.primary_identifier = $scope.alleleData.primary_identifier || '';
    $scope.alleleData.name = $scope.alleleData.name || '';
    $scope.alleleData.description = $scope.alleleData.description || '';
    $scope.alleleData.type = $scope.alleleData.type || '';
    $scope.alleleData.expression = $scope.alleleData.expression || '';
    $scope.alleleData.evidence = $scope.alleleData.evidence || '';
    $scope.alleleData.synonyms = $scope.alleleData.synonyms || [];
    $scope.alleleData.existingSynonyms = [];
    $scope.alleleData.newSynonyms = [];
    $scope.genes = null;

    $scope.data = {
      promoterGeneId: null,
      newSynonymsString: '',
    };

    $scope.userIsAdmin = CantoGlobals.current_user_is_admin;
    $scope.pathogenHostMode = CantoGlobals.pathogen_host_mode;

    $scope.showAlleleTypeField = (
      ! $scope.lockedAlleleType && (
        $scope.alleleData.type != 'aberration' ||
        $scope.alleleData.type != 'aberration wild type'
      )
    );

    function processSynonyms() {
      $.map($scope.alleleData.synonyms || [],
            function(synonymDetails) {
              if (synonymDetails.edit_status === 'existing') {
                $scope.alleleData.existingSynonyms.push(synonymDetails.synonym);
              } else {
                $scope.alleleData.newSynonyms.push(synonymDetails.synonym);
              }
            });
    }

    processSynonyms();

    $scope.data.newSynonymsString = $scope.alleleData.newSynonyms.join(' | ');

    $scope.strainData = {
      selectedStrain: null,
      showStrainPicker: CantoGlobals.strains_mode && $scope.taxonId,
      strains: null
    };

    if (CantoGlobals.strains_mode) {
      getStrainsFromServer($scope.taxonId);
    }

    $scope.showExpression = function () {
      return CantoGlobals.alleles_have_expression &&
        !!$scope.alleleData.type &&
        $scope.current_type_config != undefined &&
        $scope.current_type_config.allow_expression_change;
    };

    $scope.showPromoterOpts = function() {
      return $scope.showExpression() &&
        $scope.alleleData.expression && 
        ($scope.alleleData.expression == 'Overexpression' ||
         $scope.alleleData.expression == 'Knockdown' ||
         $scope.alleleData.expression == 'Ectopic');
    };

    $scope.getGenesFromServer = function() {
      CursGeneList.geneList().then(function (results) {
        $scope.genes = results;

        if (typeof($scope.alleleData.promoter_gene) != 'undefined') {
          $.map($scope.genes,
                (gene) => {
                  if (gene.primary_identifier == $scope.alleleData.promoter_gene) {
                    $scope.data.promoterGeneId = gene.gene_id;
                  }
                });
        }


      }).catch(function (err) {
        toaster.pop('note', "couldn't read the gene list from the server");
      });
    };

    $scope.getGenesFromServer();

    $scope.openSingleGeneAddDialog = function () {
      var modal = openSingleGeneAddDialog($uibModal);
      modal.result.then(function () {
        $scope.getGenesFromServer();
      });
    };

    $scope.strainSelected = function (strain) {
      $scope.strainData.selectedStrain = strain;
    };

    $scope.env = {};

    $scope.name_autopopulated = false;

    $scope.env.allele_type_names_promise = CantoConfig.get('allele_type_names');
    $scope.env.allele_types_promise = CantoConfig.get('allele_types');

    if ($scope.lockedAlleleType) {
      $scope.alleleData.type = $scope.lockedAlleleType;
      updateAlleleType($scope.alleleData.type, '');
    }

    $scope.env.allele_type_names_promise.then(function (data) {
      $scope.env.allele_type_names = data;
    });

    $scope.env.allele_types_promise.then(function (data) {
      $scope.env.allele_types = data;
    });

    $scope.maybe_autopopulate = function () {
      if (typeof this.current_type_config === 'undefined') {
        return '';
      }
      var autopopulate_name = this.current_type_config.autopopulate_name;
      if (typeof (autopopulate_name) === 'undefined') {
        return '';
      }

      $scope.alleleData.name =
        makeAutopopulateName(autopopulate_name, $scope.alleleData.gene_display_name);
      return this.alleleData.name;
    };

    $scope.$watch('alleleData.type', updateAlleleType);

    $scope.nameSelectedCallback = function(alleleData) {
      $scope.alleleData.primary_identifier = alleleData.primaryIdentifier;
      $scope.alleleData.name = alleleData.name;
      $scope.alleleData.description = alleleData.description;
      $scope.alleleData.type = alleleData.type;
      $scope.alleleData.synonyms = alleleData.synonyms;
      processSynonyms();
    };

    $scope.isValidType = function () {
      return !!$scope.alleleData.type;
    };

    $scope.isValidName = function () {
      return !$scope.current_type_config || !$scope.current_type_config.allele_name_required || $scope.alleleData.name;
    };

    $scope.isValidDescription = function () {
      return !$scope.current_type_config || !$scope.current_type_config.description_required || $scope.alleleData.description;
    };

    $scope.isValidExpression = function () {
      return $scope.current_type_config &&
        (!CantoGlobals.alleles_have_expression ||
         !$scope.current_type_config.expression_required ||
          $scope.alleleData.expression);
    };

    $scope.isExistingAllele = function () {
      return !!$scope.alleleData.primary_identifier;
    };

    $scope.isValidStrain = function () {
      if ($scope.strainData.showStrainPicker) {
        return $scope.strainData.selectedStrain;
      } else {
        return true;
      }
    };

    $scope.isValid = function () {
      return $scope.isValidExpression() &&
        (
          $scope.isExistingAllele() ||
          $scope.isValidType() && $scope.isValidName() &&
          $scope.isValidDescription()
        ) &&
        $scope.isValidStrain();
    };

    function splitSynonymsForStoring(alleleData, newSynonymsString) {
      alleleData.synonyms =
        $.map(alleleData.existingSynonyms,
              function(existingSynonymName) {
                return {
                  synonym: existingSynonymName,
                  edit_status: 'existing',
                };
              });
      $.map(newSynonymsString.split('|'),
            function(newSynonym) {
              var trimmedSynonym = trim(newSynonym);
              if (trimmedSynonym.length > 0) {
                alleleData.synonyms.push({
                  synonym: trimmedSynonym,
                  edit_status: 'new',
                });
              }
            });
      delete alleleData['existingSynonyms'];
      delete alleleData['newSynonyms'];
    }

    $scope.ok = function () {
      if ($scope.isValid()) {
        splitSynonymsForStoring($scope.alleleData, $scope.data.newSynonymsString);
        copyObject($scope.alleleData, args.allele);
        if ($scope.data.promoterGeneId == null) {
          args.allele.promoter_gene = null;
        } else {
          $.map($scope.genes,
                (gene) => {
                  if (gene.gene_id == $scope.data.promoterGeneId) {
                    args.allele.promoter_gene = gene.primary_identifier;
                  }
                });
        }

        if (!$scope.showPromoterOpts()) {
          delete args.allele.promoter_gene;
          delete args.allele.exogenous_promoter;
        }

        var strainName = null;
        if ($scope.strainData.selectedStrain) {
          strainName = $scope.strainData.selectedStrain.strain_name;
        }
        $uibModalInstance.close({
          alleleData: args.allele,
          strainName: strainName
        });
      } else {
        toaster.pop('error', "No changes have been made");
      }
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };

    function getStrainsFromServer(taxonId) {
      Curs.list('strain').then(function (strains) {
        $scope.strainData.strains = filterStrainsByTaxonId(strains, taxonId);
      }).catch(function () {
        toaster.pop('error', 'failed to get strain list from server');
      });
    }

    function updateAlleleType(newType, oldType) {
      $scope.env.allele_types_promise.then(function (data) {
        $scope.current_type_config = data[newType];

        if (newType === oldType) {
          return;
        }

        if ($scope.alleleData.primary_identifier) {
          return;
        }

        if ($scope.name_autopopulated) {
          if ($scope.name_autopopulated == $scope.alleleData.name) {
            $scope.alleleData.name = '';
          }
          $scope.name_autopopulated = '';
        }

        $scope.name_autopopulated = $scope.maybe_autopopulate();
        $scope.alleleData.description = '';
        $scope.alleleData.expression = '';
      });
    }
  };

canto.controller('AlleleEditDialogCtrl',
                 ['$scope', '$uibModal', '$uibModalInstance', 'toaster', 'CantoConfig', 'args',
                  'Curs', 'CursGeneList', 'CantoGlobals',
    alleleEditDialogCtrl
  ]);

var termSuggestDialogCtrl =
  function ($scope, $uibModalInstance) {
    $scope.suggestion = {
      name: '',
      definition: '',
    };

    $scope.isValidName = function () {
      return $scope.suggestion.name;
    };

    $scope.isValidDefinition = function () {
      return $scope.suggestion.definition;
    };

    $scope.isValid = function () {
      return $scope.isValidName() && $scope.isValidDefinition();
    };

    // return the data from the dialog as an Object
    $scope.dialogToData = function ($scope) {
      return {
        name: $scope.suggestion.name,
        definition: $scope.suggestion.definition,
      };
    };

    $scope.ok = function () {
      $uibModalInstance.close($scope.dialogToData($scope));
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('TermSuggestDialogCtrl',
  ['$scope', '$uibModalInstance',
    termSuggestDialogCtrl
  ]);


function storeGenotypeHelper(toaster, $http, genotype_id, genotype_name, genotype_background, alleles, taxonid, strain_name, comment) {

  var url = curs_root_uri + '/feature/genotype';

  if (genotype_id) {
    url += '/edit/' + genotype_id;
  } else {
    url += '/store';
  }

  var data = {
    genotype_name: genotype_name,
    genotype_background: genotype_background,
    genotype_comment: comment,
    alleles: alleles,
    taxonid: taxonid,
    strain_name: strain_name,
  };

  loadingStart();

  var result = $http.post(url, data);

  result.catch(function (data) {
    if (data.message) {
      toaster.error("Storing genotype failed, message from server: " + data.message);
    } else {
      toaster.error("Storing genotype failed, please reload and try again.  If that fails " +
        "please contact the curators.");
    }
  });

  result.finally(loadingEnd);

  return result
    .then(function(response) {
      return response.data;
    });
}

function makeAlleleEditInstance($uibModal, allele, taxonId, isCopied, lockedAlleleType) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/allele_edit.html',
    controller: 'AlleleEditDialogCtrl',
    title: 'Add an allele for this phenotype',
    animate: false,
    size: 'lg',
    windowClass: "modal",
    resolve: {
      args: function () {
        return {
          allele: allele,
          taxonId: taxonId,
          isCopied: isCopied,
          lockedAlleleType: lockedAlleleType
        };
      }
    },
    backdrop: 'static',
  });
}


var genePageCtrl =
  function ($scope, $uibModal, toaster, $http, CantoGlobals, CursGenotypeList, CursSettings) {
    $scope.advancedMode = function () {
      return CursSettings.getAnnotationMode() == 'advanced';
    };

    $scope.singleAlleleQuick =
      function (gene_display_name, gene_systematic_id, gene_id, annotationTypeName, taxonId) {
        var editInstance = makeAlleleEditInstance($uibModal, {
            gene_display_name: gene_display_name,
            gene_systematic_id: gene_systematic_id,
            gene_id: gene_id,
          },
          taxonId);

        editInstance.result.then(function (editResults) {
          var alleleData = editResults.alleleData;
          var strainName = editResults.strainName;
          var storePromise =
            CursGenotypeList.storeGenotype(toaster, $http, undefined, undefined, undefined,
                                           [alleleData], taxonId, strainName, undefined);

          storePromise.then(function (data) {
            if (data.status === 'error') {
              toaster.error("Storing genotype failed, message from server: " + data.message);
            } else {
              window.location.href =
                CantoGlobals.curs_root_uri + '/feature/genotype/annotate/' + data.genotype_id +
                '/start/' + annotationTypeName;
            }
          });
        });
      };
  };

canto.controller('GenePageCtrl', ['$scope', '$uibModal', 'toaster', '$http', 'CantoGlobals',
  'CursGenotypeList', 'CursSettings',
  genePageCtrl
]);


var singleGeneAddDialogCtrl =
  function ($scope, $uibModalInstance, $q, toaster, CantoService, Curs) {
    $scope.gene = {
      searchIdentifier: '',
      message: null,
      valid: false,
    };

    $scope.isValid = function () {
      return $scope.gene.primaryIdentifier != null;
    };

    var cancelPromise = null;

    $scope.$watch('gene.searchIdentifier',
      function () {
        $scope.gene.message = null;
        $scope.gene.primaryIdentifier = null;

        if (cancelPromise != null) {
          cancelPromise.resolve();
          cancelPromise = null;
        }

        if ($scope.gene.searchIdentifier.length >= 2) {
          cancelPromise = $q.defer();

          var promise = CantoService.lookup('gene', [$scope.gene.searchIdentifier],
            undefined, cancelPromise);

          promise.then(function (data) {
            if (data.missing.length > 0) {
              $scope.gene.message = 'Not found';
              $scope.gene.primaryIdentifier = null;
            } else {
              if (data.found.length > 1) {
                $scope.gene.message =
                  'There is more than one gene matching gene, try a ' +
                  'systematic ID instead: ' +
                  $.map(data.found,
                    function (gene) {
                      return gene.primary_identifier || gene.primary_name;
                    }).join(', ');
                $scope.gene.primaryIdentifier = null;
              } else {
                $scope.gene.message = 'Found: ';

                if (data.found[0].primary_name) {
                  $scope.gene.message +=
                    data.found[0].primary_name + '(' + data.found[0].primary_identifier + ')';
                } else {
                  $scope.gene.message += data.found[0].primary_identifier;
                }
                $scope.gene.primaryIdentifier = data.found[0].primary_identifier;
              }
            }
          });
        }
      });

    $scope.ok = function () {
      var promise = Curs.add('gene', [$scope.gene.primaryIdentifier]);

      promise.then(function (data) {
          if (data.status === 'error') {
            toaster.pop('error', data.message);
          } else {
            if (data.gene_id == null) {
              // null if the gene was already in the list
              toaster.pop('info', $scope.gene.primaryIdentifier +
                ' is already added to this session');
            }
            $uibModalInstance.close({
              new_gene_id: data.gene_id,
            });
          }
        })
        .catch(function () {
          toaster.pop('error', 'Failed to add gene, could not contact the Canto server');
        });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('SingleGeneAddDialogCtrl',
  ['$scope', '$uibModalInstance', '$q', 'toaster', 'CantoService', 'Curs',
    singleGeneAddDialogCtrl
  ]);

var genotypeEdit =
  function ($http, $uibModal, CantoConfig, CantoGlobals, Curs, toaster) {
    return {
      scope: {
        editOrDuplicate: '@',
        genotypeId: '@',
        storedCallback: '&',
        cancelCallback: '&',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_edit.html',
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.multi_organism_mode = CantoGlobals.multi_organism_mode;
        $scope.strains_mode = CantoGlobals.strains_mode;
        $scope.allow_single_wildtype_allele = CantoGlobals.allow_single_wildtype_allele;
        $scope.allelesHaveExpression = CantoGlobals.alleles_have_expression;

        $scope.strainSelected = function (strain) {
          $scope.data.selectedStrainName = strain ?
            strain.strain_name :
            null;
        };

        $scope.getGenesFromServer = function () {
          Curs.list('gene').then(function (results) {
            var genes = results;
            genes = setGeneNames(genes);

            var currentTaxonId = $scope.data.taxonId;
            if (currentTaxonId) {
              genes = filterGenesByOrganism(genes, currentTaxonId);
            }
            $scope.genes = genes;
          }).catch(function () {
            toaster.pop('error', 'failed to get gene list from server');
          });
        };

        function getStrainsFromServer(taxonId) {
          Curs.list('strain').then(function (strains) {
            $scope.strains = filterStrainsByTaxonId(strains, taxonId);
          }).catch(function () {
            toaster.pop('error', 'failed to get strain list from server');
          });
        }

        function filterGenesByOrganism(genes, taxonId) {
          return $.grep(genes, function (gene) {
            return gene.organism.taxonid == taxonId;
          });
        }

        function setGeneNames(genes) {
          $.map(genes, function (gene) {
            gene.display_name = gene.primary_name || gene.primary_identifier;
          });
          return genes;
        }

        $scope.reset = function () {
          $scope.genes = [];
          $scope.strains = [];

          $scope.data = {
            annotationCount: 0,
            genotypeName: null,
            genotypeBackground: null,
            genotypeComment: null,
            selectedStrainName: null,
            strainName: null,
            taxonId: null,
            alleles: [],
            alleleGroups: [],
          };

          $scope.wildTypeCheckPasses = true;
        };

        $scope.reset();
        reload();

        function processAlleles(alleles) {
          var alleleGroupMap = { haploid: [] };
          $.map(alleles,
                function(allele) {
                  if (allele.diploid_name) {
                    if (!(allele.diploid_name in alleleGroupMap)) {
                      alleleGroupMap[allele.diploid_name] = [];
                    }
                    alleleGroupMap[allele.diploid_name].push(allele);
                  } else {
                    alleleGroupMap.haploid.push(allele);
                  }
                });

          var haploidAlleles = alleleGroupMap['haploid'];
          delete alleleGroupMap['haploid'];

          var alleleGroups = [];

          var idx = 1;
          Object.keys(alleleGroupMap).forEach(function(groupName) {
            var groupAlleles = alleleGroupMap[groupName];
            if (groupAlleles.length == 1) {
              haploidAlleles.push(groupAlleles[0]);
            } else {
              alleleGroups.push({ name: idx, alleles: groupAlleles });
              idx++;
            }
          });

          if (haploidAlleles.length > 0) {
            // make sure hapoids come first
            alleleGroups.unshift({ name: 'haploid', alleles: haploidAlleles });
          }

          return alleleGroups;
        }

        function reload() {

          if ($scope.genotypeId) {
            if ($scope.editOrDuplicate == 'edit') {
              $scope.data.genotype_id = $scope.genotypeId;
            }
            Curs.details('genotype', ['by_id', $scope.genotypeId])
              .then(function (genotypeDetails) {
                $scope.data.alleles = genotypeDetails.alleles;
                $scope.data.genotypeName = genotypeDetails.name;
                $scope.data.genotypeBackground = genotypeDetails.background;
                $scope.data.genotypeComment = genotypeDetails.comment;
                $scope.data.annotationCount = genotypeDetails.annotation_count;
                $scope.data.taxonId = genotypeDetails.organism.taxonid;
                $scope.data.strainName = genotypeDetails.strain_name;
                $scope.data.organismName = genotypeDetails.organism.scientific_name;

                $scope.getGenesFromServer();
                getStrainsFromServer($scope.data.taxonId);
              });
          } else {
            $scope.getGenesFromServer();
          }
        }

        $scope.env = {
          cursConfigPromise: CantoConfig.get('curs_config')
        };

        $scope.$watch('data.alleles',
          function () {
            $scope.data.alleleGroups = processAlleles($scope.data.alleles);
            $scope.env.cursConfigPromise.then(function (data) {
              $scope.data.genotype_long_name =
                data.genotype_config.default_strain_name +
                " " +
                $.map($scope.data.alleles, function (val) {
                  var newName = val.name || 'no_name';
                  if (val.description === '') {
                    newName += "(" + val.type + ")";
                  } else {
                    newName += "(" + val.description + ")";
                  }
                  if (val.expression !== '') {
                    newName += "[" + val.expression + "]";
                  }
                  return newName;
                }).join(" ");
            });

            $scope.wildTypeCheckPasses = $scope.checkWildtypeExpression();
          },
          true);

        // check for endogenous wild types allele where there isn't a
        // allele of the same gene
        // See: https://github.com/pombase/canto/issues/797
        $scope.checkWildtypeExpression = function () {
          if ($scope.allow_single_wildtype_allele) {
            return true;
          }

          var wildTypeStates = {};

          $.map($scope.data.alleles,
            function (allele) {
              var currentState = wildTypeStates[allele.gene_id];

              if (currentState == 'seen_non_wt_product_level_wt') {
                return;
              }

              if (allele.type != 'wild type' ||
                allele.expression != 'Wild type product level') {
                wildTypeStates[allele.gene_id] = 'seen_non_wt_product_level_wt';
                return;
              } else {
                wildTypeStates[allele.gene_id] = 'seen_wt_product_level';
              }
            });

          var wildTypeCheckPasses = true;

          $.each(wildTypeStates,
            function (idx, state) {
              if (state == 'seen_wt_product_level') {
                wildTypeCheckPasses = false;
              }
            });

          return wildTypeCheckPasses;
        };

        $scope.store = function () {
          var result = storeGenotypeHelper(
            toaster,
            $http,
            $scope.data.genotype_id,
            $scope.data.genotypeName,
            $scope.data.genotypeBackground,
            $scope.data.alleles,
            $scope.data.taxonId,
            $scope.data.selectedStrainName,
            $scope.data.genotypeComment
         );

          result.then(function (data) {
            if (data.status === "success") {
              if ($scope.data.genotype_id) {
                toaster.pop('info', "Successfully stored changes");
              } else {
                toaster.pop('info', "Created new genotype: " + data.genotype_display_name);
              }
              $scope.storedCallback({
                genotypeId: data.genotype_id
              });
              $scope.reset();
            } else {
              if (data.status === "existing") {
                toaster.pop('error', "Can't store - there is an existing genotype with the same alleles: " + data.genotype_display_name);
              } else {
                toaster.pop('error', data.message);
              }
            }
          }).
          catch(function (data, status) {
            toaster.pop('error', "Accessing server failed: " + (data || status));
          });
        };

        $scope.removeAllele = function (allele) {
          $scope.data.alleles.splice($scope.data.alleles.indexOf(allele), 1);
        };

        $scope.allelesEqual = function (allele1, allele2) {
          return allele1.type === allele2.type &&
            allele1.gene_id === allele2.gene_id &&
            (allele1.expression || '') === (allele2.expression || '') &&
            (allele1.name || '') === (allele2.name || '') &&
            (allele1.promoter_gene || '') === (allele2.promoter_gene || '') &&
            (allele1.exogenous_promoter || '') === (allele2.exogenous_promoter || '');
        };

        $scope.findExistingAllele = function (alleleData) {
          var foundAllele = null;

          $.map($scope.data.alleles,
            function (existingAllele) {
              if ($scope.allelesEqual(existingAllele, alleleData)) {
                foundAllele = existingAllele;
              }
            });

          return foundAllele;
        };

        $scope.openAlleleEditDialog =
          function (isNewAllele, allele) {
            if (allele.gene) {
              allele.gene_display_name = allele.gene.display_name;
              allele.gene_systematic_id = allele.gene.primary_identifier;
              allele.gene_id = allele.gene.gene_id;
              delete allele.gene;
            }

            var editInstance =
              makeAlleleEditInstance($uibModal, allele);

            editInstance.result.then(function (editResults) {
              var editedAllele = editResults.alleleData;
              if (isNewAllele) {
                if ($scope.findExistingAllele(editedAllele)) {
                  toaster.pop({
                    type: 'warning',
                    title: 'Warning: adding duplicate allele',
                    timeout: 10000,
                    showCloseButton: true
                  });
                }
                $scope.data.alleles.push(editedAllele);
              }
            });
          };

        $scope.openSingleGeneAddDialog = function () {
          var modal = openSingleGeneAddDialog($uibModal);
          modal.result.then(function () {
            $scope.getGenesFromServer();
          });
        };

        $scope.cancel = function () {
          $scope.cancelCallback();
        };

        $scope.isValid = function () {
          return $scope.data.alleles.length > 0 && $scope.wildTypeCheckPasses;
        };
      }
    };
  };

canto.directive('genotypeEdit',
  ['$http', '$uibModal', 'CantoConfig', 'CantoGlobals', 'Curs', 'toaster',
    genotypeEdit
  ]);


var genotypeViewCtrl =
  function ($scope, CantoGlobals, CursSettings) {
    var ctrl = this;

    $scope.init = function (annotationCount, organismType) {
      $scope.annotationCount = annotationCount;
      ctrl.organismType = organismType;
      ctrl.genotypeManagePath = getGenotypeManagePath(ctrl.organismType);
    };

    $scope.advancedMode = function () {
      return CursSettings.getAnnotationMode() == 'advanced';
    };

    $scope.editGenotype = function (genotypeId) {
      window.location.href =
        CantoGlobals.curs_root_uri +
        '/' + ctrl.genotypeManagePath +
        '#/edit/' + genotypeId;
    };

    $scope.backToGenotypes = function () {
      window.location.href = CantoGlobals.curs_root_uri +
        '/' + ctrl.genotypeManagePath +
        (CantoGlobals.read_only_curs ? '/ro' : '');
    };
  };

canto.controller('GenotypeViewCtrl',
  ['$scope', 'CantoGlobals', 'CursSettings', genotypeViewCtrl]);


var metagenotypeViewCtrl =
  function ($scope, CantoGlobals, CursSettings) {
    $scope.init = function (annotationCount) {
      $scope.annotationCount = annotationCount;
    };

    $scope.advancedMode = function () {
      return CursSettings.getAnnotationMode() == 'advanced';
    };

    $scope.editMetagenotype = function (metagenotypeId) {
      window.location.href =
        CantoGlobals.curs_root_uri + '/metagenotype_manage#/edit/' + metagenotypeId;
    };

    $scope.toMetagenotypeManagement = function () {
      window.location.href = CantoGlobals.curs_root_uri +
        '/metagenotype_manage' + (CantoGlobals.read_only_curs ? '/ro' : '');
    };

    $scope.toSummaryPage = function () {
      window.location.href = CantoGlobals.curs_root_uri +
      (CantoGlobals.read_only_curs ? '/ro' : '');
    };
  };

canto.controller('MetagenotypeViewCtrl',
  ['$scope', 'CantoGlobals', 'CursSettings', metagenotypeViewCtrl]);

var organismSelector = function () {
  return {
    scope: {
      organismSelected: '&',
      organisms: '<',
      initialSelectionTaxonId: '@',
      label: '@',
      allowUnset: '<',
    },
    restrict: 'E',
    templateUrl: app_static_path + 'ng_templates/organism_selector.html',
    controller: organismSelectorCtrl,
  };
};

var organismSelectorCtrl = function ($scope, CantoGlobals) {

  $scope.app_static_path = CantoGlobals.app_static_path;

  $scope.data = {
    selectedOrganism: null
  };

  $scope.organismChanged = function () {
    $scope.organismSelected({
      organism: $scope.data.selectedOrganism
    });
  };

  $scope.unsetOrganism = function () {
    $scope.data.selectedOrganism = null;
    $scope.organismChanged();
  };

  $scope.$watch('organisms', function () {
    if ($scope.organisms && $scope.organisms.length > 0)
      if ($scope.organisms.length === 1) {
          $scope.data.selectedOrganism = $scope.organisms[0];
        $scope.organismChanged();
      } else {
        if ($scope.initialSelectionTaxonId) {
          var matchingOrganisms =
              $.grep($scope.organisms,
                     function (organism) {
                       return organism.taxonid == $scope.initialSelectionTaxonId;
                     });
          $scope.data.selectedOrganism = matchingOrganisms[0];
          $scope.organismChanged();
          $scope.initialSelectionTaxonId = null;
        }
      }
  });
};

canto.directive('organismSelector', organismSelector);

var strainSelector = function () {
  return {
    scope: {
      strains: '<',
      strainSelected: '&',
      styleClass: '@?'
    },
    restrict: 'E',
    templateUrl: app_static_path + 'ng_templates/strain_selector.html',
    controller: strainSelectorCtrl
  };
};

var strainSelectorCtrl = function ($scope, CantoGlobals) {

  $scope.app_static_path = CantoGlobals.app_static_path;

  $scope.data = {
    selectedStrain: null,
    styleClass: computeStyleClass($scope.styleClass)
  };

  $scope.strainChanged = function () {
    $scope.strainSelected({
      strain: $scope.data.selectedStrain
    });
  };

  function computeStyleClass(className) {
    return className === undefined ? 'form-control' : className;
  }

  $scope.$watch('strains', function () {
    if ($scope.strains && $scope.strains.length === 1) {
      $scope.data.selectedStrain = $scope.strains[0];
      $scope.strainChanged();
    }
  });
};

canto.directive('strainSelector', ['CantoGlobals', strainSelector]);

function GenotypeGeneList() {
  return {
    scope: {
      genotypes: '<',
      genes: '<',
      genotypeType: '<'
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/genotype_gene_list.html',
    controller: 'genotypeGeneListCtrl'
  };
};

canto.directive('genotypeGeneList', [GenotypeGeneList]);

function GenotypeGeneListCtrl(
  $scope, $uibModal, $http, Curs, CursGenotypeList, CantoGlobals, CantoConfig, toaster
) {
  $scope.curs_root_uri = CantoGlobals.curs_root_uri;
  $scope.read_only_curs = CantoGlobals.read_only_curs;
  $scope.multiOrganismMode = CantoGlobals.multi_organism_mode;
  $scope.showQuickDeletionButtons = CantoGlobals.show_quick_deletion_buttons;
  $scope.showQuickWildTypeButtons = CantoGlobals.show_quick_wild_type_buttons;
  $scope.columnCount = getColumnCount();

  var hasDeletionHash = {};
  var selectedStrain = '';

  $scope.$watch('genotypes', makeHasDeletionHash, true);

  $scope.hasDeletionGenotype = function(geneId) {
    return !$scope.multiOrganismMode && !!hasDeletionHash[geneId];
  };

  $scope.singleAlleleQuick = function (geneDisplayName, geneSystematicId, geneId, lockedAlleleType) {
    var gene = getGeneById(geneId);
    var isCopied = false;

    if (!gene) {
      return;
    }

    var taxonId = gene.organism.taxonid;
    var editInstance = makeAlleleEditInstance(
      $uibModal,
      {
        gene_display_name: geneDisplayName,
        gene_systematic_id: geneSystematicId,
        gene_id: geneId,
      },
      taxonId,
      isCopied,
      lockedAlleleType
    );

    editInstance.result.then(function (editResults) {
      var alleleData = editResults.alleleData;
      var strainName = editResults.strainName;
      var storePromise = CursGenotypeList.storeGenotype(
        toaster,
        $http,
        undefined,
        undefined,
        undefined,
        [alleleData],
        taxonId,
        strainName,
        undefined
      );

      storePromise.then(function (data) {
        window.location.href = CantoGlobals.curs_root_uri +
          '/' + getGenotypeManagePath($scope.genotypeType) +
          '#/select/' +
          data.genotype_id;
      });
    });
  };

  $scope.quickWildType = function (geneDisplayName, geneSystematicId, geneId) {
    var lockedAlleleType = 'wild type';
    $scope.singleAlleleQuick(geneDisplayName, geneSystematicId, geneId, lockedAlleleType);
  };

  $scope.quickDeletion = CantoGlobals.strains_mode ?
    deleteSelectStrainPicker :
    makeDeletionAllele;

  $scope.deletionButtonTitle = function (geneId) {
    if (hasDeletionHash[geneId]) {
      return 'A deletion genotype already exists for this gene';
    } else {
      return 'Add a deletion genotype for this gene';
    }
  };

  function deleteSelectStrainPicker(geneId) {
    var gene = getGeneById(geneId);
    var taxonId = gene.organism.taxonid;
    var deleteInstance = selectStrainPicker($uibModal, taxonId);

    deleteInstance.result.then(function (strain) {
      selectedStrain = strain.strain.strain_name;
      makeDeletionAllele(geneId);
    });
  };

  function getGeneById(geneId) {
    if ($scope.genes) {
      for (var i = 0, len = $scope.genes.length; i < len; i++) {
        // find gene by ID
        if ($scope.genes[i].gene_id == geneId) {
          return $scope.genes[i];
        }
      }
    }
    return null;
  };

  function makeDeletionAllele(geneId) {
    var gene = getGeneById(geneId);

    if (!gene) {
      return;
    }

    var displayName = gene.primary_name || gene.primary_identifier;

    var deletionAllele = {
      description: "",
      expression: "",
      gene_display_name: displayName,
      gene_id: geneId,
      gene_systematic_id: gene.primary_identifier,
      name: displayName + "delta",
      primary_identifier: "",
      type: "deletion",
    };

    var taxonId = gene.organism.taxonid;
    var storePromise = CursGenotypeList.storeGenotype(
      toaster,
      $http,
      undefined,
      undefined,
      undefined,
      [deletionAllele],
      taxonId,
      selectedStrain,
      undefined
    );

    storePromise.then(function (data) {
      if (data.status === "existing") {
        toaster.pop('info', "Using existing genotype: " + data.genotype_display_name);
      } else {
        window.location.href = CantoGlobals.curs_root_uri +
          '/' + getGenotypeManagePath($scope.genotypeType) +
          '#/select/' +
          data.genotype_id;
      }
    });
  };

  function makeHasDeletionHash() {
    hasDeletionHash = {};
    $scope.genotypes.map(function (genotype) {
      if (genotype.alleles.length === 1) {
        var allele = genotype.alleles[0];
        if (allele.type === 'deletion') {
          hasDeletionHash[allele.gene_id] = true;
        }
      }
    });
  };

  function getColumnCount() {
    var columnCount = 1;
    if ($scope.showQuickDeletionButtons) {
      columnCount += 1;
    }
    if ($scope.showQuickWildTypeButtons) {
      columnCount += 1;
    }
    return columnCount;
  }
}

canto.controller('genotypeGeneListCtrl', [
  '$scope', '$uibModal', '$http', 'Curs', 'CursGenotypeList',
  'CantoGlobals', 'CantoConfig', 'toaster', GenotypeGeneListCtrl
]);



var genotypeManageCtrl =
  function ($uibModal, $location, $http, Curs, CursGenotypeList, CantoGlobals,
            CantoConfig, CursGeneList, toaster) {
    return {
      scope: {
        genotypeType: '@',
      },
      replace: true,
      restrict: 'E',
      templateUrl: app_static_path + 'ng_templates/genotype_manage.html',
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.pathogen_host_mode = CantoGlobals.pathogen_host_mode;
        $scope.metagenotypeUrl = CantoGlobals.curs_root_uri + '/metagenotype_manage';

        $scope.data = {
          organisms: [],
          singleAlleleGenotypes: [],
          singleLocusDiploids: [],
          multiAlleleGenotypes: [],
          multiLocusDiploids: [],
          allGenes: [],
          visibleGenes: [],
          waitingForServer: true,
          selectedOrganism: null,
          selectedGenotypeId: null,
          editingGenotype: false,
          editGenotypeId: null,
          multiOrganismMode: false,
          hostOrganismExists: false,
          pathogenGenotypeExists: false,
          isMetagenotypeLinkDisabled: true,
        };

        $scope.data.multiOrganismMode = CantoGlobals.multi_organism_mode;
        $scope.data.splitGenotypesByOrganism = CantoGlobals.split_genotypes_by_organism;
        $scope.data.showGenotypeManagementGenesList =
          CantoGlobals.show_genotype_management_genes_list;

        $scope.updateGenes = function() {
          CursGeneList.geneList().then(function (results) {
            $scope.data.allGenes = results;
            if (!$scope.data.multiOrganismMode || !$scope.data.splitGenotypesByOrganism) {
              $scope.data.visibleGenes = results;
            }
          }).catch(function () {
            toaster.pop('note', "couldn't read the gene list from the server");
          });
        };

        $scope.updateGenes();

        $scope.openSingleGeneAddDialog = function () {
          var modal = openSingleGeneAddDialog($uibModal);
          modal.result.then(function() {
            $scope.updateVisibleGenes();
            $scope.updateGenes();
          });
        };

        $scope.organismUpdated = function (organism) {
          $scope.data.selectedOrganism = organism;
          $scope.updateGenotypeLists();
          $scope.updateVisibleGenes();
        };

        var readOrganisms = function () {
          Curs.list('organism').then(function (organisms) {
            $scope.data.hostOrganismExists = organisms.some(function (org) {
              return org.pathogen_or_host === 'host';
            });
            $scope.data.organisms = filterOrganisms(organisms, $scope.genotypeType);
          }).catch(function (res) {
            toaster.pop('error', "couldn't read the organism list from the server");
            $scope.data.waitingForServer = false;
          });
        };

        function hashChangedHandler() {
          var hash = $location.path();

          if (hash) {
            var res = /^\/(select|edit|duplicate)\/(\d+)$/.exec(hash);
            if (res) {
              if (res[1] == 'select') {
                $scope.data.selectedGenotypeId = res[2];
              } else {
                if (res[1] == 'edit' || res[1] == 'duplicate') {
                  $scope.data.editOrDuplicate = res[1];
                  $scope.data.editGenotypeId = res[2];
                  $scope.data.editingGenotype = true;
                }
              }
            }
          }
        }

        hashChangedHandler();
        window.addEventListener('hashchange', hashChangedHandler);

        $scope.cancelEdit = function () {
          $scope.data.editingGenotype = false;
          $location.path('/select/' + $scope.data.editGenotypeId);
          $scope.data.editGenotypeId = null;
        };

        $scope.storedCallback = function () {
          if ($scope.data.editGenotypeId) {
            $location.path('/select/' + $scope.data.editGenotypeId);
          }
          $scope.data.editingGenotype = false;
          $scope.data.editGenotypeId = null;
          $scope.readGenotypes();
        };

        $scope.readGenotypesCallback = function () {
          $scope.readGenotypes();
        };

        $scope.readGenotypes = function () {
          CursGenotypeList.cursGenotypeList({
            include_allele: 1
          }).then(function (results) {
            $scope.data.allGenotypes = results;
            $scope.updateGenotypeLists();
            $scope.data.waitingForServer = false;
            $scope.data.pathogenGenotypeExists = findPathogenGenotype(results);
            $scope.data.isMetagenotypeLinkDisabled = isMetagenotypeLinkDisabled();
            CursGenotypeList.onListChange($scope.readGenotypesCallback);
          }).catch(function () {
            toaster.pop('error', "couldn't read the genotype list from the server");
            $scope.data.waitingForServer = false;
          });
        };

        $scope.updateVisibleGenes = function() {
          // genes that should be shown in the genotype-gene-list
          if ($scope.data.selectedOrganism) {
            $scope.data.visibleGenes.length = 0;
            $.map($scope.data.selectedOrganism.genes,
              function(gene) {
                var geneCopy = {};
                copyObject(gene, geneCopy);
                geneCopy.organism = $scope.data.selectedOrganism;
                $scope.data.visibleGenes.push(geneCopy);
              });
          }
        };

        $scope.updateGenotypeLists = function () {
          var selectedOrganism = $scope.data.selectedOrganism;
          var allGenotypes = $scope.data.allGenotypes;

          $scope.data.singleAlleleGenotypes = [];
          $scope.data.singleLocusDiploids = [];
          $scope.data.multiAlleleGenotypes = [];
          $scope.data.multiLocusDiploids = [];

          if (allGenotypes) {
            $.map(allGenotypes,
                  function (genotype) {
                    if ($scope.data.multiOrganismMode && $scope.data.splitGenotypesByOrganism) {
                      if (!selectedOrganism) {
                        return;
                      }
                      if (genotype.organism.taxonid !== selectedOrganism.taxonid) {
                        return;
                      }
                    }

                    if (isSingleLocusGenotype(genotype)) {
                      if (isSingleLocusDiploid(genotype)) {
                        $scope.data.singleLocusDiploids.push(genotype);
                      } else {
                        $scope.data.singleAlleleGenotypes.push(genotype);
                      }
                    } else { // multi-locus genotype
                      if (isMultiLocusDiploid(genotype)) {
                        $scope.data.multiLocusDiploids.push(genotype);
                      } else {
                        $scope.data.multiAlleleGenotypes.push(genotype);
                      }
                    }
                  });
          }
        };

        $scope.showNoGenotypeNotice = function () {
          return $scope.data.selectedOrganism &&
            $scope.data.singleAlleleGenotypes.length === 0 &&
            $scope.data.multiAlleleGenotypes.length === 0;
        };

        $scope.backToSummary = function () {
          window.location.href = CantoGlobals.curs_root_uri +
            (CantoGlobals.read_only_curs ? '/ro' : '');
        };

        $scope.toMetagenotype = function () {
          window.location.href = $scope.metagenotypeUrl +
            (CantoGlobals.read_only_curs ? '/ro' : '');
        };

        function findPathogenGenotype(genotypes) {
          return genotypes.some(function (g) {
            return g.organism.pathogen_or_host === 'pathogen';
          });
        }

        function isMetagenotypeLinkDisabled() {
          return ! ($scope.data.pathogenGenotypeExists && $scope.data.hostOrganismExists);
        }

        readOrganisms();
        $scope.readGenotypes();

      },
    };
  };

canto.directive('genotypeManage',
  ['$uibModal', '$location', '$http', 'Curs', 'CursGenotypeList',
    'CantoGlobals', 'CantoConfig', 'CursGeneList', 'toaster',
    genotypeManageCtrl
  ]);


var geneSelectorCtrl =
  function (CursGeneList, $uibModal, toaster) {
    return {
      scope: {
        selectedGenes: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/gene_selector.html',
      controller: function ($scope) {
        $scope.data = {
          genes: [],
        };

        function getGenesFromServer() {
          CursGeneList.geneList().then(function (results) {
            $scope.data.genes = results;
          }).catch(function () {
            toaster.pop('note', "couldn't read the gene list from the server");
          });
        }

        getGenesFromServer();

        $scope.addAnotherGene = function () {
          var modal = openSingleGeneAddDialog($uibModal);
          modal.result.then(function () {
            getGenesFromServer();
          });
        };

      },
      link: function (scope) {
        scope.selectedGenesFilter = function () {
          scope.selectedGenes = $.grep(scope.data.genes, function (gene) {
            return gene.selected;
          });
        };
      },
    };
  };

canto.directive('geneSelector',
  ['CursGeneList', '$uibModal', 'toaster',
    geneSelectorCtrl
  ]);

var genotypeSearchCtrl =
  function (CursGenotypeList, CantoGlobals) {
    return {
      scope: {},
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_search.html',
      controller: function ($scope) {
        $scope.data = {
          filteredCursGenotypes: [],
          filteredExternalGenotypes: [],
          searchGenes: [],
          waitingForServerCurs: false,
          waitingForServerExternal: false,
        };
        $scope.app_static_path = CantoGlobals.app_static_path;

        $scope.addGenotype = function () {
          window.location.href = CantoGlobals.curs_root_uri + '/feature/genotype/add';
        };

        $scope.waitingForServer = function () {
          return $scope.data.waitingForServerCurs || $scope.data.waitingForServerExternal;
        };

        $scope.filteredGenotypeCount = function () {
          return $scope.data.filteredCursGenotypes.length +
            $scope.data.filteredExternalGenotypes.length;
        };
      },
      link: function (scope) {
        scope.$watch('data.searchGenes',
          function () {
            if (scope.data.searchGenes.length == 0) {
              scope.data.filteredCursGenotypes.length = 0;
              scope.data.filteredExternalGenotypes.length = 0;
            } else {
              scope.data.waitingForServerCurs = true;
              scope.data.waitingForServerExternal = true;
              var geneIdentifiers = $.map(scope.data.searchGenes,
                function (gene_data) {
                  return gene_data.primary_identifier;

                });
              CursGenotypeList.filteredGenotypeList('curs_only', {
                gene_identifiers: geneIdentifiers
              }).then(function (results) {
                scope.data.filteredCursGenotypes = results;
                scope.data.waitingForServerCurs = false;
                delete scope.data.serverError;
              }).catch(function () {
                scope.data.waitingForServerCurs = false;
                scope.data.serverError = "couldn't read the genotype list from the server";
              });
              CursGenotypeList.filteredGenotypeList('external_only', {
                gene_identifiers: geneIdentifiers
              }).then(function (results) {
                scope.data.filteredExternalGenotypes = results;
                scope.data.waitingForServerExternal = false;
                delete scope.data.serverError;
              }).catch(function () {
                scope.data.waitingForServerExternal = false;
                scope.data.serverError = "couldn't read the genotype list from the server";
              });
            }
          });
      },
    };
  };


var genotypeBackgroundEditDialogCtrl =
  function ($scope, $uibModalInstance, $http, toaster, CursGenotypeList, args) {
    $scope.data = {
      background: args.genotype.background
    };

    $scope.finish = function () {
      if ($scope.data.background === args.genotype.background) {
        $uibModalInstance.close();
      } else {
        var storePromise =
          CursGenotypeList.setGenotypeBackground(toaster, $http, args.genotype,
            $scope.data.background);
        storePromise.then(function () {
          $uibModalInstance.close();
        });
      }
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('GenotypeBackgroundEditDialogCtrl',
  ['$scope', '$uibModalInstance', '$http', 'toaster', 'CursGenotypeList',
    'args',
    genotypeBackgroundEditDialogCtrl
  ]);


function editBackgroundDialog($uibModal, genotype) {
  var editInstance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/genotype_background_edit.html',
    controller: 'GenotypeBackgroundEditDialogCtrl',
    title: 'Edit genotype background',
    animate: false,
    //    size: 'lg',
    resolve: {
      args: function () {
        return {
          genotype: genotype,
        };
      }
    },
    backdrop: 'static',
  });

  return editInstance.result;
}


var alleleNotesEditDialogCtrl =
    function ($scope, $uibModalInstance, $http, $q, toaster, CantoConfig, Curs,
              CantoGlobals, CursAlleleList, args) {
    $scope.noteTypes = [];

    $scope.allele = args.allele;
    $scope.readOnly = args.readOnly;

    var notesCopy = {};
    copyObject(args.allele.notes, notesCopy);

    $scope.viewAlleles = {};
    $scope.viewAllelesIds = [];
    $scope.chosenViewAlleleId = null;
    $scope.showViewAllelesPanel = true;
    $scope.closeIconPath = CantoGlobals.app_static_path + '/images/close_icon.png';

    $scope.hideViewAllelesPanel = function() {
      $scope.showViewAllelesPanel = false;
    };

    CursAlleleList.allAlleles()
      .then(function (res) {
        $.map(res, function(allele) {
          if ($scope.allele.allele_id !== allele.allele_id) {
            $scope.viewAlleles[allele.allele_id] = allele;
            $scope.viewAllelesIds.push(allele.allele_id);
          }
        });
      })
      .catch(function () {
        toaster.pop("failed to lookup alleles for: " + $scope.allele.gene_systematic_id);
      });

    CantoConfig.get('allele_note_types')
      .then(function (results) {
        $scope.noteTypes = results;
        $.map(results,
              function(noteTypeConf) {
                if (!notesCopy[noteTypeConf.name]) {
                  notesCopy[noteTypeConf.name] = '';
                }
              });
      });

    $scope.data = {
      notes: notesCopy,
    };

    $scope.finish = function () {
      var promises = [];

      if ($scope.readOnly) {
        $uibModalInstance.close();
        return;
      }

      $.map($scope.noteTypes,
            function(noteTypeConf) {
              var noteTypeName = noteTypeConf.name;
              if ($scope.data.notes[noteTypeName].trim().length == 0) {
                delete $scope.data.notes[noteTypeName];
              }

              if ($scope.data.notes[noteTypeName] != args.allele.notes[noteTypeName]) {
                var promise;
                var newValue = $scope.data.notes[noteTypeName];
                if (newValue) {
                  var setArgs = [args.allele.uniquename, noteTypeName, { data: newValue }];
                  promise = Curs.set('allele_note', setArgs);
                  promise.then(function() {
                    args.allele.notes[noteTypeName] = newValue;
                  });
                } else {
                  promise = Curs.delete('allele_note', args.allele.uniquename, noteTypeName);
                  promise.then(function() {
                    delete args.allele.notes[noteTypeName];
                  });
                }
                promises.push(promise);
              }
            });

      $q.all(promises).then(function () {
        $uibModalInstance.close();
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('AlleleNotesEditDialogCtrl',
  ['$scope', '$uibModalInstance', '$http', '$q', 'toaster', 'CantoConfig', 'Curs',
   'CantoGlobals', 'CursAlleleList', 'args',
    alleleNotesEditDialogCtrl
  ]);

function editNotesDialog($uibModal, allele, readOnly) {
  var editInstance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/allele_notes_edit.html',
    controller: 'AlleleNotesEditDialogCtrl',
    title: 'Edit new note',
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          allele: allele,
          readOnly: readOnly
        };
      }
    },
    backdrop: 'static',
  });

  return editInstance.result;
}

function viewNotesDialog($uibModal, allele) {
  return editNotesDialog($uibModal, allele, true);
}


canto.directive('genotypeSearch',
  ['CursGenotypeList', 'CantoGlobals',
    genotypeSearchCtrl
  ]);


function getDisplayLoci(alleles) {
  var diploidMap = {};
  var displayLoci = [];

  $.map(alleles,
        function(allele) {
          if (allele.diploid_name) {
            if (!diploidMap[allele.diploid_name]) {
              diploidMap[allele.diploid_name] = [];
            }
            diploidMap[allele.diploid_name].push(allele);
          } else {
            displayLoci.push(allele);
          }
        });

  Object.keys(diploidMap).forEach(function(diploidName) {
    var alleles = diploidMap[diploidName];

    var type;

    if (alleles.length == 2) {
      type = 'diploid';
    } else {
      type = 'multiploid';
    }

    var alleleDisplayNames =
        $.map(alleles,
              function(allele) {
                return allele.long_display_name;
              });

    var displayName = alleleDisplayNames.join(' / ');

    var geneDisplayName = null;

    $.map(alleles,
          function(allele) {
            if (allele.gene_display_name && !geneDisplayName) {
              geneDisplayName = allele.gene_display_name;
            }
          });

    var diploidLocus = {
      gene_display_name: geneDisplayName,
      gene_id: alleles[0].gene_id,
      type: type,
      long_display_name: displayName,
    };

    displayLoci.unshift(diploidLocus);
  });

  return displayLoci;
}


var genotypeListRowLinksCtrl =
  function ($uibModal, $http, toaster, CantoConfig, CantoGlobals, CursGenotypeList, AnnotationTypeConfig) {
    return {
      restrict: 'E',
      scope: {
        genotypes: '=',
        genotypeId: '=',
        alleleCount: '@',
        annotationCount: '@',
        interactionCount: '@',
      },
      replace: true,
      templateUrl: CantoGlobals.app_static_path + 'ng_templates/genotype_list_row_links.html',
      controller: function ($scope) {
        $scope.userIsAdmin = CantoGlobals.current_user_is_admin;

        var genotype =
          $.grep($scope.genotypes, function (genotype) {
            return genotype.genotype_id === $scope.genotypeId;
          })[0];
        var genotypePathogenOrHost = genotype.organism.pathogen_or_host;

        $scope.genotypeManagePath = getGenotypeManagePath(
          genotypePathogenOrHost
        );

        $scope.canDelete = true;
        $scope.deleteTitle = '';

        if ($scope.annotationCount > 0) {
          $scope.canDelete = false;
          $scope.deleteTitle =
            'Genotypes with annotations cannot be deleted - delete the annotations first';
        } else {
          if ($scope.interactionCount > 0) {
            $scope.canDelete = false;
            $scope.deleteTitle =
              'This genotype is part of an interaction so cannot be deleted';
          } else {
            if (Object.keys(genotype.metagenotype_count_by_type).length > 0) {
              $scope.canDelete = false;
              if (genotype.metagenotype_count_by_type['pathogen-host']) {
                $scope.deleteTitle =
                  'This genotype is part of a metagenotype - delete the metagenotype(s) first';
              } else {
                var metagenotypeType = (Object.keys(genotype.metagenotype_count_by_type))[0];
                $scope.deleteTitle =
                  'First delete the ' + metagenotypeType + '(s) that contain this genotype';
              }
            }
          }
        }

        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.pathogen_host_mode = CantoGlobals.pathogen_host_mode;

        $scope.matchingAnnotationTypes = [];

        AnnotationTypeConfig.getAll().then(function (data) {
          $scope.matchingAnnotationTypes =
            $.grep(data,
              function (annotationType) {
                if (annotationType.feature_type !== 'genotype') {
                  return false;
                }

                if (annotationType.direct_editing_disabled) {
                  return false;
                }

                if ($scope.pathogen_host_mode &&
                  genotypePathogenOrHost !== annotationType.feature_subtype) {
                  return false;
                }

                return true;
              });
        });

        $scope.editGenotype = function (genotypeId) {
          window.location.href =
            CantoGlobals.curs_root_uri +
            '/' + getGenotypeManagePath(genotypePathogenOrHost) +
            '#/edit/' + genotypeId;
        };

        $scope.editAllele = function (genotypeId, isCopied) {
          var genotypePromise = CursGenotypeList.getGenotypeById(genotypeId);

          genotypePromise.then(function (genotype) {
            var allele = genotype.alleles[0];

            if (allele.gene) {
              allele.gene_display_name = allele.gene.display_name;
              allele.gene_systematic_id = allele.gene.primary_identifier;
              allele.gene_id = allele.gene.gene_id;
              delete allele.gene;
            }
            var editInstance =
              makeAlleleEditInstance($uibModal, allele, genotype.organism.taxonid, isCopied);

            editInstance.result.then(function (editResults) {
              var editedAllele = editResults.alleleData;
              var strainName = editResults.strainName;
              var storePromise =
                CursGenotypeList.storeGenotype(toaster, $http, undefined, undefined,
                  undefined, [editedAllele],
                  genotype.organism.taxonid, strainName, undefined);

              storePromise.then(function (data) {
                window.location.href =
                  CantoGlobals.curs_root_uri +
                  '/' + getGenotypeManagePath(genotypePathogenOrHost) +
                  '#/select/' + data.genotype_id;
              });
            });
          });
        };

        $scope.deleteGenotype = function (genotypeId) {
          loadingStart();

          var q = CursGenotypeList.deleteGenotype($scope.genotypes, genotypeId);

          q.then(function () {
            toaster.pop('success', 'Genotype deleted');
          });

          q.catch(function (message) {
            if (message.match('genotype .* has annotations')) {
              toaster.pop('warning', "couldn't delete the genotype: delete the annotations that use it first");
            } else {
              toaster.pop('error', "couldn't delete the genotype: " + message);
            }
          });

          q.finally(function () {
            loadingEnd();
          });
        };

        $scope.editBackground = function (genotypeId) {
          var genotypePromise = CursGenotypeList.getGenotypeById(genotypeId);

          genotypePromise.then(function (genotype) {
            editBackgroundDialog($uibModal, genotype);
          });
        };

        var noteTypeNames = [];

        CantoConfig.get('allele_note_types')
          .then(function (results) {
            noteTypeNames = $.map(results,
                                  function(noteTypeConf) {
                                    return noteTypeConf.name;
                                  });
          });

        $scope.showNotesLink = function () {
          return genotype.alleles.length == 1 && noteTypeNames.length > 0;
        };

        $scope.editNotes = function () {
          editNotesDialog($uibModal, genotype.alleles[0]);
        };

        $scope.viewNotes = function() {
          viewNotesDialog($uibModal, genotype.alleles[0]);
        };
      },
      link: function ($scope) {
        $scope.detailsUrl = '#';
        $scope.viewAnnotationUri =
          CantoGlobals.curs_root_uri + '/feature/genotype/view/' + $scope.genotypeId;
        if (CantoGlobals.read_only_curs) {
          $scope.viewAnnotationUri += '/ro';
        }
      },
    };
  };

canto.directive('genotypeListRowLinks',
  ['$uibModal', '$http', 'toaster', 'CantoConfig','CantoGlobals', 'CursGenotypeList',
    'AnnotationTypeConfig',
    genotypeListRowLinksCtrl
  ]);

var genotypeListRowCtrl =
  function ($uibModal, CantoGlobals) {
    return {
      restrict: 'A',
      scope: {
        genotypes: '=',
        genotype: '=',
        checkBoxIsChecked: '=',
        showCheckBoxActions: '=',
        checkBoxChange: '&',
        selectedGenotypeId: '@',
        setSelectedGenotypeId: '&',
        navigateOnClick: '@',
        columnsToHide: '=',
      },
      replace: true,
      templateUrl: CantoGlobals.app_static_path + 'ng_templates/genotype_list_row.html',
      controller: function ($scope) {
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.alleles_have_expression = CantoGlobals.alleles_have_expression;
        $scope.closeIconPath = CantoGlobals.app_static_path + '/images/close_icon.png';
        $scope.multi_organism_mode = CantoGlobals.multi_organism_mode;
        $scope.userIsAdmin = CantoGlobals.current_user_is_admin;

        $scope.displayLoci = getDisplayLoci($scope.genotype.alleles);

        $scope.isSelected = function () {
          return $scope.selectedGenotypeId &&
            $scope.selectedGenotypeId == $scope.genotype.genotype_id;
        };

        if ($scope.genotype.alleles.length == 1) {
          $scope.firstAlleleComment = $scope.genotype.alleles[0].comment;
        } else {
          $scope.firstAlleleComment = null;
        }

        $scope.encodeSymbols = encodeSymbol;

        $scope.clearSelection = function () {
          $scope.setSelectedGenotypeId({
            genotypeId: null
          });
          var links = $('#curs-genotype-list-row-actions');
          links.remove();
        };

        $scope.showEditNotesLink = function() {
          return $scope.genotype.alleles.length == 1 &&
            Object.keys($scope.genotype.alleles[0].notes).length > 0;
        };

        $scope.editNotes = function() {
          editNotesDialog($uibModal, $scope.genotype.alleles[0]);
        };

        $scope.viewNotes = function() {
          viewNotesDialog($uibModal, $scope.genotype.alleles[0]);
        };

        $scope.viewAlleleComment = function(allele) {
          openSimpleDialog($uibModal, 'Allele comment',
                           'Allele comment for ' + allele.display_name,
                           allele.comment);
        };

        $scope.strain = $scope.genotype.strain_name;

        $scope.mouseOver = function () {
          if ($scope.navigateOnClick != 'true') {
            $scope.setSelectedGenotypeId({
              genotypeId: $scope.genotype.genotype_id
            });
          }
        };
      },
      link: function ($scope) {
        if ($scope.navigateOnClick) {
          $scope.detailsUrl =
            CantoGlobals.curs_root_uri + '/feature/genotype/view/' +
            $scope.genotype.id_or_identifier +
            (CantoGlobals.read_only_curs ? '/ro' : '');
        } else {
          $scope.detailsUrl = '#';
        }
      },
    };
  };

canto.directive('genotypeListRow',
  ['$uibModal', 'CantoGlobals',
    genotypeListRowCtrl
  ]);


var alleleSelectorCtrl =
  function ($uibModal, toaster) {
    return {
      scope: {
        alleles: '=',
        disableSelector: '=',
        initialSelectedAllele: '@',
        alleleSelected: '&',
        mousedownHandler: '&',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/allele_selector.html',
      controller: function ($scope) {
        $scope.selectedAllele = $scope.initialSelectedAllele;

        $scope.handleMousedown = function() {
          $scope.mousedownHandler();
        };

        $scope.selectionChanged = function() {
          $scope.alleleSelected({ alleleId: $scope.selectedAllele });
        };
      },
    };
  };

canto.directive('alleleSelector',
                ['$uibModal', 'toaster',
                 alleleSelectorCtrl
                ]);


var diploidConstructorDialogCtrl =
    function ($scope, $uibModalInstance, CantoGlobals, CantoConfig, toaster, args) {
      $scope.startAllele = args.startAllele;
      $scope.diploidType = 'homozygous';
      $scope.selectorAlleles = [];

      $scope.isWTAndWTExpression = function(allele) {
        return allele.type === "wild type" &&
               (typeof allele.expression == "undefined" ||
               allele.expression == "Wild type product level")
      };

      $scope.startAlleleIsWTAndWTExpression =
        $scope.isWTAndWTExpression($scope.startAllele);

      $.map(args.alleles,
            function(allele) {
              var displayName = allele.long_display_name;
              if (allele.allele_id === $scope.startAllele.allele_id) {
                return;
              }

              if ($scope.isWTAndWTExpression(allele)) {
                return;
              }

              $scope.selectorAlleles.push({
                alleleId: allele.allele_id,
                displayName: displayName,
              });
            });

      $scope.selectedAlleleId = null;

      if ($scope.selectorAlleles.length > 0) {
        $scope.selectedAlleleId = $scope.selectorAlleles[0].alleleId;
      }

      $scope.alleleSelectorMousedown = function() {
        $scope.diploidType = 'other';
      };

      $scope.alleleSelected = function(selectedAlleleId) {
        $scope.selectedAlleleId = selectedAlleleId;
      };

      $scope.isValid = function() {
        return true;
      };

      $scope.ok = function () {
        return CantoConfig.get('wildtype_name_template')
          .then(function (data) {
            var nameTemplate = data.value;
            var otherAllele;

            if ($scope.diploidType === 'wild type') {
              var geneDisplayName = $scope.startAllele.gene_display_name;
              var otherAlleleType;
              if ($scope.startAllele.type === 'aberration') {
                otherAlleleType = 'aberration wild type';
              } else {
                otherAlleleType = 'wild type';
              }
              var otherAlleleName;
              if ($scope.startAllele.type === 'aberration') {
                otherAlleleName = makeAutopopulateName(nameTemplate, $scope.startAllele.name);
              } else {
                otherAlleleName = makeAutopopulateName(nameTemplate, geneDisplayName);
              }
              otherAllele = {
                name: otherAlleleName,
                gene_id: $scope.startAllele.gene_id,
                type: otherAlleleType,
              };
              if (CantoGlobals.alleles_have_expression) {
                otherAllele['expression'] = "Wild type product level";
              }
            } else {
              if ($scope.diploidType === 'homozygous') {
                otherAllele = $scope.startAllele;
              } else {
                otherAllele = $.grep(args.alleles,
                                     function(allele) {
                                       return allele.allele_id === $scope.selectedAlleleId;
                                     })[0];
              }
            }

            $uibModalInstance.close({
              diploidAlleles: [$scope.startAllele, otherAllele],
            });
          });
      };

      $scope.cancel = function () {
        $uibModalInstance.dismiss('cancel');
      };
    };

canto.controller('DiploidConstructorDialogCtrl',
                 ['$scope', '$uibModalInstance', 'CantoGlobals', 'CantoConfig', 'toaster', 'args',
                  diploidConstructorDialogCtrl
                 ]);

function makeDiploidConstructorInstance($uibModal, startAllele, alleles) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/diploid_constructor.html',
    controller: 'DiploidConstructorDialogCtrl',
    title: 'Create a diploid genotype',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function () {
        return {
          startAllele: startAllele,
          alleles: alleles,
        };
      }
    },
    backdrop: 'static',
  });
}


var genotypeListViewCtrl =
  function ($compile, $http, $uibModal, toaster, CursGenotypeList, CantoGlobals) {
    return {
      scope: {
        genotypeList: '=',
        diploidList: '=',
        selectedGenotypeId: '=',
        showCheckBoxActions: '=',
        navigateOnClick: '@'
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_list_view.html',
      controller: function ($scope) {
        $scope.multi_organism_mode = CantoGlobals.multi_organism_mode;
        $scope.alleles_have_expression = CantoGlobals.alleles_have_expression;
        $scope.diploid_mode = CantoGlobals.diploid_mode;

        function hasDifferentStrains(genotypes) {
          var firstStrain = genotypes[0].strain_name;
          var strainsAreEqual = genotypes.every(function (genotype) {
            return genotype.strain_name === firstStrain;
          });
          return !strainsAreEqual;
        }

        function getOrganismType(genotypes) {
          if (CantoGlobals.pathogen_host_mode && genotypes.length > 0) {
            var genotype = genotypes[0];
            if ('organism' in genotype) {
              var organism = genotype.organism;
              if ('pathogen_or_host' in organism) {
                return organism.pathogen_or_host;
              }
            }
          }
          return 'normal';
        }

        function getHiddenColumnsCount() {
          var key;
          var count = 0;
          for (key in $scope.columnsToHide) {
            if ($scope.columnsToHide.hasOwnProperty(key) &&
              $scope.columnsToHide[key] === true) {
              count += 1;
            }
          }
          return count;
        }

        $scope.organismType = getOrganismType($scope.genotypeList);

        $scope.checkBoxChecked = {};

        $scope.columnsToHide = {
          background: true,
          name: true,
          strain: true
        };

        $scope.hiddenColumnsCount = Object.keys($scope.columnsToHide).length;

        $scope.selectedGenotypes = function () {
          var retVal = [];
          var checkFunc =
              function (genotype) {
                if ($scope.checkBoxChecked[genotype.genotype_id]) {
                  retVal.push(genotype);
                }
              };
          $.map($scope.genotypeList, checkFunc);
          $.map($scope.diploidList, checkFunc);
          return retVal;
        };

        $scope.checkedGenotypeCount = function () {
          return $scope.selectedGenotypes().length;
        };

        $scope.validForDiploid = function() {
          var selectedGenotypes = $scope.selectedGenotypes();
          if (selectedGenotypes.length !== 1) {
            return false;
          }

          var selectedGenotype = selectedGenotypes[0];

          if (selectedGenotype.alleles.length > 1) {
            return false;
          }

          if (selectedGenotype.alleles[0].diploid_name) {
            return false;
          }

          return true;
        };

        $scope.selectNone = function () {
          $scope.checkBoxChecked = {};
        };

        $scope.combineGenotypes = function () {
          var checkedGenotypes =
            $.grep($scope.genotypeList.concat($scope.diploidList),function (genotype) {
              return !!$scope.checkBoxChecked[genotype.genotype_id];
            });

          if (hasDifferentStrains(checkedGenotypes)) {
            toaster.pop(
              'warning',
              "Can't create a multi-allele genotype from different strains."
            );
            return;
          }

          var allelesForGenotype = [];

          $.map(checkedGenotypes,
                function (genotype) {
                  $.map(genotype.alleles,
                        function(allele) {
                          allelesForGenotype.push(allele);
                        });
                });

          var newBackgroundParts = [];

          $.map(checkedGenotypes, function (genotype) {
            if (genotype.background) {
              if ($.grep(newBackgroundParts,
                  function (background) {
                    return background === genotype.background;
                  }).length === 0) {
                newBackgroundParts.push(genotype.background);
              }
            }
          });

          var newBackground = undefined;

          if (newBackgroundParts.length > 0) {
            newBackground = newBackgroundParts.join(' ');
          }

          var strain = $scope.genotypeList[0].strain_name;
          var taxonid = $scope.genotypeList[0].organism.taxonid;

          var newComment = '';

          $.map(checkedGenotypes,
                function(genotype) {
                  if (genotype.comment) {
                    if (newComment) {
                      newComment += ' ';
                    }
                    newComment += genotype.comment;
                  }
                });

          var storePromise =
            CursGenotypeList.storeGenotype(toaster, $http, undefined, undefined, newBackground, allelesForGenotype, taxonid, strain, newComment);

          storePromise.then(function (data) {
            if (data.status === 'existing') {
              toaster.pop('info',
                          'Using existing genotype: ' + data.genotype_display_name);
            } else {
              toaster.pop({
                type: 'success',
                title: 'Genotype stored successfully',
              });
            }

            window.location.href =
              CantoGlobals.curs_root_uri +
              '/' + getGenotypeManagePath($scope.organismType) +
              '#/select/' + data.genotype_id;
          });
        };

        $scope.createDiploid = function () {
          var selectedGenotypes =
            $.grep($scope.genotypeList, function (genotype) {
              return !!$scope.checkBoxChecked[genotype.genotype_id];
            });

          var selectedAlleles =
            $.map(selectedGenotypes, function (genotype) {
              return genotype.alleles[0];
            });

          var strain = $scope.genotypeList[0].strain_name;
          var taxonid = $scope.genotypeList[0].organism.taxonid;

          var startAllele = {};
          copyObject(selectedGenotypes[0].alleles[0], startAllele);

          var sameGeneAlleles = [];

          if (!startAllele.type.startsWith('aberration')) {
              $.map($scope.genotypeList,
                    function(genotype) {
                      if (genotype.alleles.length !== 1) {
                        return false;
                      }

                      var allele = genotype.alleles[0];

                      if (allele.gene_id === startAllele.gene_id) {
                        sameGeneAlleles.push(allele);
                      }
                    });
          }

          var aberrationAlleles = [];

          $.grep($scope.genotypeList,
                 function(genotype) {
                   if (genotype.alleles.length !== 1) {
                     return false;
                   }

                   var allele = genotype.alleles[0];

                   if (allele.type.startsWith('aberration')) {
                     aberrationAlleles.push(allele);
                   }
                 });

          var allelesForDiploid = sameGeneAlleles;

          $.map(aberrationAlleles,
                function(aberration) {
                  allelesForDiploid.push(aberration);
                });

          var diploidPromise =
              makeDiploidConstructorInstance($uibModal, selectedAlleles[0], allelesForDiploid);

          diploidPromise.result.then(function (result) {
            var diploidAlleles = result.diploidAlleles;

            $.map(diploidAlleles,
                  function(allele) {
                    // the diploid_name is used only to group alleles together
                    // into a Diploid in the DB
                    // we only have one diploid so we don't have to try hard
                    // create a unique diploid name
                    allele.diploid_name = 'diploid-1';
                  });

            var storePromise =
              CursGenotypeList.storeGenotype(toaster, $http, undefined, undefined,
                                             undefined, diploidAlleles, taxonid,
                                             strain, undefined);

            storePromise.then(function (result) {
              if (result.status === 'existing') {
                toaster.pop('info',
                            'Using existing genotype: ' + result.genotype_display_name);
              } else {
                toaster.pop({
                  type: 'success',
                  title: 'Genotype stored successfully',
                });
                $scope.checkBoxChecked = {};
              }
            });
          });
        };

        $scope.setSelectedGenotypeId = function (genotypeId) {
          $scope.selectedGenotypeId = genotypeId;
        };

        $scope.$watch('genotypeList',
          function () {
            $scope.columnsToHide = {
              background: true,
              name: true,
              strain: true,
            };
            var allGenotypes;
            if ($scope.diploid_mode) {
              allGenotypes = $scope.genotypeList.concat($scope.diploidList);
            } else {
              allGenotypes = $scope.genotypeList;
            }
            $.map(allGenotypes,
              function (genotype) {
                if (genotype.background) {
                  $scope.columnsToHide.background = false;
                }
                if (genotype.name) {
                  $scope.columnsToHide.name = false;
                }
                if (genotype.strain_name) {
                  $scope.columnsToHide.strain = false;
                }
              });
            $scope.hiddenColumnsCount = getHiddenColumnsCount();
          }, true);
      },
    };
  };

canto.directive('genotypeListView',
                ['$compile', '$http', '$uibModal',
                 'toaster', 'CursGenotypeList', 'CantoGlobals',
                 genotypeListViewCtrl
                ]);


var singleGeneGenotypeList =
  function (CursGenotypeList, CantoGlobals) {
    return {
      scope: {
        genePrimaryIdentifier: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/single_gene_genotype_list.html',
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.data = {
          filteredGenotypes: [],
          waitingForServer: true,
          showAll: false,
        };

        $scope.shouldShowAll = function () {
          return $scope.data.showAll;
        };

        $scope.showAll = function () {
          $scope.data.showAll = true;
        };

        $scope.hideAll = function () {
          $scope.data.showAll = false;
        };

        CursGenotypeList.filteredGenotypeList('curs_only', {
          gene_identifiers: [$scope.genePrimaryIdentifier],
        }).then(function (results) {
          $scope.data.filteredGenotypes = results;
          $scope.data.waitingForServer = false;
          if (results.length > 0 && results.length <= 5) {
            $scope.data.showAll = true;
          }
          delete $scope.data.serverError;
        }).catch(function () {
          $scope.data.waitingForServer = false;
          $scope.data.serverError = "couldn't read the genotype list from the server";
        });

      },
    };
  };

canto.directive('singleGeneGenotypeList',
  ['CursGenotypeList', 'CantoGlobals', singleGeneGenotypeList]);


var genotypeAlleles =
  function (CantoGlobals) {
    return {
      scope: {
        genotype: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_alleles.html',
      controller: function ($scope) {
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
      }
    };
  };


canto.directive('genotypeAlleles',
  ['CantoGlobals', genotypeAlleles]);

var genotypeDetails =
  function (CantoGlobals) {
    return {
      scope: {
        genotype: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_details.html',
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
      }
    };
  };


canto.directive('genotypeDetails',
                ['CantoGlobals', '$uibModal', genotypeDetails]);


canto.service('CantoConfig', function ($http) {
  this.promises = {};

  this.get = function (key) {
    if (!this.promises[key]) {
      this.promises[key] =
        $http({
          method: 'GET',
          url: application_root + '/ws/canto_config/' + key
        })
        .then(function(response) {
          return response.data;
        });
    }
    return this.promises[key];
  };
});

canto.service('AnnotationTypeConfig', function (CantoConfig, $q) {
  this.getAll = function () {
    if (typeof (this.listPromise) === 'undefined') {
      this.listPromise = CantoConfig.get('annotation_type_list');
    }

    return this.listPromise;
  };
  this.getByKeyValue = function (key, value) {
    var q = $q.defer();

    this.getAll().then(function (annotationTypeList) {
      var filteredAnnotationTypes =
        $.grep(annotationTypeList,
          function (annotationType) {
            return annotationType[key] === value;
          });
      if (filteredAnnotationTypes.length > 0) {
        q.resolve(filteredAnnotationTypes[0]);
      } else {
        q.resolve(undefined);
      }
    }).catch(function (response) {
      if (response.status) {
        q.reject();
      } // otherwise the request was cancelled
    });

    return q.promise;

  };
  this.getByName = function (typeName) {
    return this.getByKeyValue('name', typeName);
  };
  this.getByNamespace = function (namespace) {
    return this.getByKeyValue('namespace', namespace);
  };
});


var uploadGenesCtrl = function ($scope, Curs) {
  $scope.data = {
    geneIdentifiers: '',
    selectedHostOrganisms: [],
    noAnnotation: false,
    noAnnotationReason: '',
    otherText: '',
    serverGeneList: null,
  };

  Curs.list('gene').then(function (results) {
    $scope.data.serverGeneList = results;
  });

  $scope.isValid = function () {
    return ($scope.data.geneIdentifiers.length > 0 ||
        ($scope.data.selectedHostOrganisms.length > 0 &&
          $scope.data.serverGeneList &&
          $scope.data.serverGeneList.length > 0)) ||
      ($scope.data.noAnnotation &&
        $scope.data.noAnnotationReason.length > 0 &&
        ($scope.data.noAnnotationReason !== "Other" ||
          $scope.data.otherText.length > 0));
  };
};

canto.controller('UploadGenesCtrl', ['$scope', 'Curs', uploadGenesCtrl]);


function SubmitToCuratorsCtrl($scope) {
  $scope.data = {
    reason: null,
    otherReason: '',
    hasAnnotation: false
  };
  $scope.noAnnotationReasons = [];

  $scope.init = function (reasons) {
    $scope.noAnnotationReasons = reasons;
  };

  $scope.validReason = function () {
    return $scope.data.reason != null && $scope.data.reason.length > 0 &&
      ($scope.data.reason !== 'Other' || $scope.data.otherReason.length > 0);
  };
}

canto.controller('SubmitToCuratorsCtrl', SubmitToCuratorsCtrl);

var termConfirmDialogCtrl =
  function ($scope, $uibModalInstance, CantoService, CantoGlobals, CantoConfig, args) {
    $scope.app_static_path = CantoGlobals.app_static_path;

    $scope.data = {
      initialTermId: args.termId,
      featureType: args.featureType,
      isExtensionTerm: args.isExtensionTerm,
      state: 'definition',
      termDetails: null,
      doNotAnnotateCurrentTerm: false,
    };

    $scope.checkDoNotAnnotate = function (configDoNotAnnotateSubsets) {
      $scope.data.doNotAnnotateCurrentTerm =
        arrayIntersection(configDoNotAnnotateSubsets,
          $scope.data.termDetails.subset_ids).length > 0;
    };

    $scope.setTerm = function (termId) {
      var promise = CantoService.lookup('ontology', [termId], {
        def: 1,
        children: 1,
        subset_ids: 1,
      });

      promise.then(function (termDetails) {
        $scope.data.termDetails = termDetails;

        $scope.doNotAnnotateCurrentTerm = false;

        // See: https://github.com/pombase/canto/issues/1517
        if (!$scope.data.isExtensionTerm) {
          CantoConfig.get('ontology_namespace_config')
            .then(function (data) {
              $scope.ontology_namespace_config = data;
              var doNotAnnotateSubsets =
                  data['do_not_annotate_subsets'] || [];

              $scope.checkDoNotAnnotate(doNotAnnotateSubsets);
            });
        }

        if (args.initialState) {
          $scope.data.state = args.initialState;
          delete args.initialState;
        } else {
          $scope.data.state = 'definition';
        }
      });
    };

    $scope.setTerm($scope.data.initialTermId);

    $scope.gotoChild = function (childId) {
      $scope.setTerm(childId);
    };

    $scope.next = function () {
      $scope.data.state = 'children';
    };

    $scope.back = function () {
      $scope.data.state = 'definition';
    };

    $scope.finish = function () {
      $uibModalInstance.close({
        newTermId: $scope.data.termDetails.id,
        newTermName: $scope.data.termDetails.name
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };


canto.controller('TermConfirmDialogCtrl',
  ['$scope', '$uibModalInstance', 'CantoService', 'CantoGlobals',
    'CantoConfig', 'args',
    termConfirmDialogCtrl
  ]);


var termDefinitionDisplayCtrl =
  function () {
    return {
      scope: {
        termDetails: '=',
        matchingSynonym: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/term_definition.html',
    };
  };

canto.directive('termDefinitionDisplay', [termDefinitionDisplayCtrl]);


var termChildrenDisplayCtrl =
  function (CantoGlobals) {
    return {
      scope: {
        termDetails: '=',
        gotoChildCallback: '&',
        doNotAnnotateCurrentTerm: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/term_children.html',
      controller: function ($scope) {
        $scope.CantoGlobals = CantoGlobals;
        $scope.gotoChild = function (childId) {
          $scope.gotoChildCallback({
            childId: childId
          });
        };
      },
    };
  };

canto.directive('termChildrenDisplay',
  ['CantoGlobals',
    termChildrenDisplayCtrl
  ]);


var GenotypeInteractionAnnotationTableCtrl =
  function ($uibModal, CantoConfig, CantoGlobals) {
    return {
      scope: {
        interactions: '=',
        phenotypeAnnotationType: '<',
        showDoubleMutantPhenotype: '<',
        showPhenotypesLink: '<',
        allowDeletion: '<',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_interaction_annotation_table.html',
      controller: function ($scope) {
        $scope.ready = false;
        $scope.evidenceTypes = {};

        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.read_only_curs = CantoGlobals.read_only_curs;

        CantoConfig.get('evidence_types').
          then(function(result) {
            $scope.evidenceTypes = result;
            $scope.ready = true;
          });

        $scope.getDisplayEvidence = function(interaction) {
          var interactionType = interaction.interaction_type;
          if ($scope.evidenceTypes[interactionType] &&
             $scope.evidenceTypes[interactionType].name) {
            return $scope.evidenceTypes[interactionType].name;
          } else {
            return interactionType;
          }
        };

        $scope.genotypeAPhenotypes = function(interaction) {
          if (interaction.genotype_a_phenotype_annotations) {
              return interaction.genotype_a_phenotype_annotations;
          } else {
            return [];
          }
        };

        $scope.viewPhenotypes = function(interaction) {
          startViewInteractionPhenotypes($uibModal, interaction.genotype_a,
                                         $scope.phenotypeAnnotationType,
                                         interaction.genotype_a_phenotype_annotations);
        };

        $scope.deleteInteraction = function(interaction) {
          var idx = $scope.interactions.indexOf(interaction);

          $scope.interactions.splice(idx, 1);
        };
      },
    };
  };

canto.directive('genotypeInteractionAnnotationTable',
                ['$uibModal', 'CantoConfig', 'CantoGlobals',
                 GenotypeInteractionAnnotationTableCtrl]);


var viewInteractionPhenotypesDialogCtrl =
  function ($scope, $uibModalInstance,
            CantoGlobals, Curs, toaster, args) {
    $scope.data = {};

    $scope.data.genotype = args.genotype;
    $scope.data.annotationType = args.annotationType;
    $scope.data.annotations = args.annotations;

    $scope.ok = function () {
      $uibModalInstance.dismiss('ok');
    };
  };

canto.controller('ViewInteractionPhenotypesDialogCtrl',
  ['$scope', '$uibModalInstance',
   'CantoGlobals', 'Curs', 'toaster', 'args',
    viewInteractionPhenotypesDialogCtrl
  ]);


function startViewInteractionPhenotypes($uibModal, genotype,
                                        annotationType, annotations) {
  var instance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/view_interaction_phenotypes.html',
    controller: 'ViewInteractionPhenotypesDialogCtrl',
    title: 'Interaction phenotypes',
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          genotype: genotype,
          annotationType: annotationType,
          annotations: annotations,
        };
      }
    },
    backdrop: 'static',
  });

  return instance.result;
}


var selectInteractionAnnotationsCtrl =
  function ($http, $uibModal,
            CantoGlobals, CursGenotypeList, Curs, toaster)
{
   return {
     scope: {
       subjectAllele: '<',
       subjectGenotype: '<',
       objectAllele: '<',
       annotationType: '<',
       interactionTypeConfig: '<',
       subjectAnnotations: '<',
       interactingAnnotations: '=',
     },
     restrict: 'E',
     replace: true,
     templateUrl: app_static_path + 'ng_templates/select_interaction_annotations.html',
     controller: function ($scope) {
     },
     link: function ($scope) {
       $scope.data = {};

       $scope.data.selectedAnnotationIds = [];

       $scope.data.annotationsById = {};

       $.map($scope.subjectAnnotations,
             function(annotation) {
               $scope.data.annotationsById[annotation.annotation_id] = annotation;
             });

       $scope.selectionChanged = function(annotationIds) {
         $scope.data.selectedAnnotationIds = annotationIds;

         $scope.interactingAnnotations.length = 0;

         $.map($scope.data.selectedAnnotationIds,
                function(annotationId) {
                  const annotation = $scope.data.annotationsById[annotationId];
                  $scope.interactingAnnotations.push(annotation);
                });
       };

       $scope.canSelect = function() {
         return $scope.data.selectedAnnotationIds.length > 0;
       };

       $scope.okButtonTitleMessage = function() {
         return "Select";
       };

       function popupAnnotationEdit(genotype) {
         var termConstraint;

         if ($scope.annotationType.associated_interaction_annotation_type) {
           var termConstraints =
               $scope.annotationType.associated_interaction_annotation_type.interaction_single_allele_phenotype_constraints;
//           termConstraint = termConstraints['Synthetic Rescue'];
         }

         var addPromise =
             addAnnotation($uibModal, $scope.annotationType.name,
                           'genotype',
                           genotype.genotype_id,
                           genotype.genotype_display_name,
                           genotype.taxonid, termConstraint);

         addPromise.then(function (newAnnotation) {
           $scope.interactingAnnotations.push(newAnnotation);
         });
       }

       $scope.addPhenotypeAnnotation = function() {
         // need to store subjectAllele as a new genotype and use it as
         // subjectGenotype

         if ($scope.subjectGenotype) {
           popupAnnotationEdit($scope.subjectGenotype);
         } else {
           var storePromise =
               CursGenotypeList.storeGenotype(toaster, $http, undefined, undefined, undefined,
                                              [$scope.subjectAllele],
                                              undefined, undefined, undefined);

           storePromise.then(function(storedGenotype) {
             popupAnnotationEdit(storedGenotype);
           });
         }
       };
     }
   };
};

canto.directive('selectInteractionAnnotations',
                ['$http', '$uibModal',
                  'CantoGlobals', 'CursGenotypeList', 'Curs', 'toaster',
                  selectInteractionAnnotationsCtrl
                 ]);


function filterAnnotationsByFeature(annotations, feature) {
  return $.grep(annotations,
               function(annotation) {
                 return annotation.feature_id == feature.feature_id;
               });
}

var AnnotationInteractionsEditDialogCtrl =
  function ($scope, $uibModalInstance, $uibModal,
            CantoGlobals, Curs, CursGenotypeList, toaster, args) {
    const defaultTitle = 'Add interaction';
    const titleForAddingPhenotype = 'Select phenotype for interaction';

    $scope.data = {
      modalTitle: defaultTitle,
      interactionForward: null,
      annotationSelectorVisible: false,
      interactionPhenotypeNotNeeded: false,
      directionSelectorVisible: false,
      alleleA: args.initialData.alleleA,
      alleleB: args.initialData.alleleB,
      alleleGenotypeA: args.initialData.alleleGenotypeA,
      alleleGenotypeB: args.initialData.alleleGenotypeB,
      annotationType: args.annotationType,
      evidenceConfig: args.initialData.evidenceConfig,
      genotypeAnnotationsA: args.initialData.genotypeAnnotationsA,
      genotypeAnnotationsB: args.initialData.genotypeAnnotationsB,
      interactingAnnotations: [],
      subjectAnnotations: [],
      subjectAllele: null,
      subjectGenotype: null,
      objectAllele: null,
      interactionTypeConfig: null,
      overexpressedAllele: null,
    };

    $scope.interactionType = null;
    $scope.interactionTypeDisplayLabel = null;

    // for now we always show all types
    $scope.hideAsymmetricTypes = false;

    $scope.evidenceCodes = Object.keys($scope.data.evidenceConfig);

    var typeWatcher = function() {
      $scope.data.interactionPhenotypeNotNeeded = false;
      $scope.data.annotationSelectorVisible = false;
      $scope.data.directionSelectorVisible = false;
      $scope.data.interactionTypeConfig = null;
      $scope.data.overexpressedAllele = null;

      if ($scope.interactionType) {
        var evidenceConfig = $scope.data.evidenceConfig[$scope.interactionType];
        $scope.data.interactionTypeConfig = evidenceConfig;
       if (evidenceConfig.is_symmetric) {
          $scope.interactionTypeDisplayLabel = evidenceConfig.interaction_dialog_type_label;
          $scope.data.interactionPhenotypeNotNeeded  = true;
          $scope.setDirection(true);
        } else {
          $scope.interactionTypeDisplayLabel =
            evidenceConfig.non_symmetric_interaction_labels.interactor_a;
          if (evidenceConfig.interaction_does_not_need_phenotype) {
            $scope.data.interactionPhenotypeNotNeeded  = true;
            $scope.setDirection(args.initialData.overexpressedAllele != 0);
          } else {
          $scope.data.overexpressedAllele = args.initialData.overexpressedAllele;

          if ($scope.data.overexpressedAllele != null &&
              evidenceConfig.overexpression_implies_direction) {
            if ($scope.data.overexpressedAllele == 1) {
              $scope.data.interactionForward = true;
            } else {
              $scope.data.interactionForward = false;
            }
            $scope.data.directionSelectorVisible = false;
            $scope.data.annotationSelectorVisible = true;
          } else {
            $scope.data.directionSelectorVisible = true;
          }
          }
        }
      }
    };
    $scope.$watch('interactionType', typeWatcher);

    $scope.setDirection = function(isForward) {
      if (isForward) {
        $scope.data.subjectAllele = $scope.data.alleleA;
        $scope.data.subjectGenotype = $scope.data.alleleGenotypeA;
        $scope.data.objectAllele = $scope.data.alleleB;
        $scope.data.subjectAnnotations = $scope.data.genotypeAnnotationsA;
      } else {
        $scope.data.subjectAllele = $scope.data.alleleB;
        $scope.data.subjectGenotype = $scope.data.alleleGenotypeB;
        $scope.data.objectAllele = $scope.data.alleleA;
        $scope.data.subjectAnnotations = $scope.data.genotypeAnnotationsB;
      }
    };

    if (args.initialData.overexpressedAllele !== null) {
      $scope.setDirection(args.initialData.overexpressedAllele != 0);
    }

    $scope.directionChanged = function() {
      if ($scope.data.interactionForward !== null) {
        $scope.data.annotationSelectorVisible = true;
      }

      $scope.data.directionSelectorVisible = false;

      $scope.data.interactingAnnotations = [];

      $scope.setDirection($scope.data.interactionForward);

      $scope.data.interactionAnnotationType =
        $scope.data.annotationType.associated_interaction_annotation_type;

      $scope.data.selectedAnnotationIds = [];

      $scope.data.modalTitle = titleForAddingPhenotype;
    };

    $scope.canFinish = function() {
      if ($scope.data.interactingAnnotations.length > 0) {
        return true;
      }

      if ($scope.interactionType) {
        var conf = $scope.data.evidenceConfig[$scope.interactionType];

        if (conf.is_symmetric || conf.interaction_does_not_need_phenotype) {
          return true;
        }
      }

      return false;
    };

    $scope.ok = function () {
      var alleleA;
      var genotypeA;
      var alleleB;
      var genotypeB;

      if ($scope.data.interactionForward) {
        alleleA = $scope.data.alleleA;
        genotypeA = $scope.data.alleleGenotypeA;
        alleleB = $scope.data.alleleB;
        genotypeB = $scope.data.alleleGenotypeB;
      } else {
        alleleA = $scope.data.alleleB;
        genotypeA = $scope.data.alleleGenotypeB;
        alleleB = $scope.data.alleleA;
        genotypeB = $scope.data.alleleGenotypeA;
      }

      $uibModalInstance.close({
        allele_a: alleleA,
        genotype_a: genotypeA,
        allele_b: alleleB,
        genotype_b: genotypeB,
        interaction_type: $scope.interactionType,
        genotype_a_phenotype_annotations: $scope.data.interactingAnnotations,
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('AnnotationInteractionsEditDialogCtrl',
                 ['$scope', '$uibModalInstance', '$uibModal',
                  'CantoGlobals', 'Curs', 'CursGenotypeList', 'toaster', 'args',
                  AnnotationInteractionsEditDialogCtrl
                 ]);


function startInteractionAnnotationsEdit($uibModal, annotationType, initialData) {
  var selectInstance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/annotation_interaction_edit_dialog.html',
    controller: 'AnnotationInteractionsEditDialogCtrl',
    title: 'Add an interaction',
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          annotationType: annotationType,
          initialData: initialData,
        };
      }
    },
    backdrop: 'static',
  });

  return selectInstance.result;
}


function interactionEvCodesFromPhenotype(phenotypeAnnotationType, phenotypeTermDetails,
                                         genotype) {
  var interactionAnnotationType =
      phenotypeAnnotationType.associated_interaction_annotation_type;

  var evidenceCodeGroups = interactionAnnotationType.evidence_code_groups;

  if (!evidenceCodeGroups || genotype.alleles.length != 2) {
    return [phenotypeAnnotationType.associated_interaction_annotation_type.evidence_codes,
            null];
  } else {
    var popPhenotypeEvCodeConfig = evidenceCodeGroups.double_mutant_population_phenotype;

    var phenotypeEvidenceCodes = [];

    var parentConstraintParts = popPhenotypeEvCodeConfig.parent_constraint.split('|');

    const hasParent = (subsetId) => {
      return parentConstraintParts.includes(subsetId);
    };

    var isNotPopTerm = false;

    if (phenotypeTermDetails.subset_ids.filter(hasParent).length > 0 ||
        $.grep(parentConstraintParts,
               function(constraintPart) {
                 return constraintPart == 'is_a(' + phenotypeTermDetails.id + ')';
               }).length > 0) {

      if (phenotypeTermDetails.subset_ids.includes(popPhenotypeEvCodeConfig.inviable_parent_constraint) ||
          'is_a(' + phenotypeTermDetails.id + ')' == popPhenotypeEvCodeConfig.inviable_parent_constraint) {
        // add extra ev codes only valid for inviable population terms:
        $.map(popPhenotypeEvCodeConfig.inviable_only_evidence_codes || [],
              inviableEvCode => {
                phenotypeEvidenceCodes.push(inviableEvCode);
              });
      } else {
        phenotypeEvidenceCodes = [...popPhenotypeEvCodeConfig.viable_evidence_codes];
      }
    } else {
      isNotPopTerm = true;
      // isn't a population term
      phenotypeEvidenceCodes = evidenceCodeGroups.not_population_evidence_codes;
    }

    var returnEvidenceCodes = [];

    if (isNotPopTerm) {
      returnEvidenceCodes = phenotypeEvidenceCodes;
    }

    var filterEvCodes = function(evCodes) {
      if (isNotPopTerm) {
        // the term isn't a population phenotype so we already know
        // the possible evidence codes
      } else {
        $.map(phenotypeEvidenceCodes,
              function(phenotypeCode) {
                if (evCodes.includes(phenotypeCode)) {
                  returnEvidenceCodes.push(phenotypeCode);
                }
              });
      }
    };

    var allele0 = genotype.alleles[0];
    var allele1 = genotype.alleles[1];

    var overexpressedAllele = null;

    if (allele0.type == 'deletion' && allele1.type == 'deletion') {
      filterEvCodes(evidenceCodeGroups.both_alleles_deletions);
    } else {
      const allele0Overexpressed =
            allele0.expression && allele0.expression == 'Overexpression';
      const allele1Overexpressed =
            allele1.expression && allele1.expression == 'Overexpression';
      if (allele0Overexpressed || allele1Overexpressed) {
        filterEvCodes(evidenceCodeGroups.one_allele_overexpressed);

        if (!allele0Overexpressed || !allele1Overexpressed) {
          // one is not overexpressed
          if (allele0Overexpressed) {
            overexpressedAllele = 0;
          } else {
            overexpressedAllele = 1;
          }
        }
      } else {
        filterEvCodes(evidenceCodeGroups.not_double_deletion_no_overexpression);
      }
    }

    return [returnEvidenceCodes, overexpressedAllele];
  }
}


function findGenotypeInArray(genotypes, searchGenotypeId) {
  for (var i = 0; i < genotypes.length; i++) {
    var testGenotype = genotypes[i];

    if (testGenotype.genotype_id == searchGenotypeId) {
      return testGenotype;
    }
  }

  return undefined;
}

// find single allele gneotypes by allele ID
function findGenotypeInArrayByAlleleId(genotypes, searchAlleleId) {
  for (var i = 0; i < genotypes.length; i++) {
    var testGenotype = genotypes[i];

    if (testGenotype.alleles.length != 1) {
      continue;
    }
    if (testGenotype.alleles[0].allele_id === searchAlleleId) {
      return testGenotype;
    }
  }

  return undefined;
}


// if it's possible to make a genotype interaction annotation attached to
// the phenotype, return:
// {
//   alleleA: ...,
//   alleleB: ...,
//   evidenceConfig: ...        // the possible interaction types,
//   genotypeAnnotationsA: ...  // the annotations for alleleA
//   genotypeAnnotationsB: ...  // the annotations for alleleB
// }
//
// returns null if no interactions are possible
function getInteractionInitialData($q, CantoConfig,
                                   termDetailsPromise,
                                   phenotypeAnnotationType, phenotypeTermId,
                                   genotypeId, allGenotypes) {
  var evidencePromise = CantoConfig.get('evidence_types');

  return $q.all([evidencePromise, termDetailsPromise])
    .then(function(result) {
      var evidenceTypes = result[0];
      var phenotypeTermDetails = result[1];

      var genotype = findGenotypeInArray(allGenotypes, genotypeId);

      if (!genotype) {
        return null;
      }

      if (genotype.alleles.length != 2 || genotype.locus_count != 2) {
        return null;
      }

      var alleleA = genotype.alleles[0];
      var alleleB = genotype.alleles[1];

      var codeFromPhenotypeResult =
          interactionEvCodesFromPhenotype(phenotypeAnnotationType, phenotypeTermDetails,
                                          genotype);

      var genotypeInteractionEvidenceCodes = codeFromPhenotypeResult[0];
      var overexpressedAllele = codeFromPhenotypeResult[1];

      var evidenceConfig = {};

      $.map(genotypeInteractionEvidenceCodes,
            function(code) {
              evidenceConfig[code] = evidenceTypes[code];
            });

      return {
        alleleA: alleleA,
        alleleB: alleleB,
        evidenceConfig: evidenceConfig,
        overexpressedAllele: overexpressedAllele,
      };
    });
}


function findGenotypesOfAlleles(data, $q, AnnotationProxy,
                                phenotypeAnnotationType, allGenotypes) {

  if (data == null) {
    return $q.when(null);
  }

  var annotationsPromise =
      AnnotationProxy.getAnnotation(phenotypeAnnotationType.name);

  return annotationsPromise.then(function(annotations) {

    var alleleA = data.alleleA;
    var alleleB = data.alleleB;

    var alleleGenotypeA = findGenotypeInArrayByAlleleId(allGenotypes, alleleA.allele_id);
    var alleleGenotypeB = findGenotypeInArrayByAlleleId(allGenotypes, alleleB.allele_id);

    var genotypeAnnotationsA = [];

    if (alleleGenotypeA) {
      genotypeAnnotationsA = filterAnnotationsByFeature(annotations, alleleGenotypeA);
    }

    var genotypeAnnotationsB = [];

    if (alleleGenotypeB) {
      genotypeAnnotationsB = filterAnnotationsByFeature(annotations, alleleGenotypeB);
    }

    data.alleleGenotypeA = alleleGenotypeA;
    data.alleleGenotypeB = alleleGenotypeB;
    data.genotypeAnnotationsA = genotypeAnnotationsA;
    data.genotypeAnnotationsB = genotypeAnnotationsB;

    return data;
  });

}

function createMissingGenotypesOfAlleles(data, $q, $http, toaster, CursGenotypeList) {
  if (data == null) {
    return $q.when(null);
  }

  var genotypeAPromise = null;
  var genotypeBPromise = null;

  if (data.alleleGenotypeA) {
    genotypeAPromise = $q.when(data.alleleGenotypeA);
  } else {
    genotypeAPromise =
      CursGenotypeList.storeGenotype(toaster, $http, undefined, undefined, undefined,
                                     [data.alleleA],
                                     undefined, undefined, undefined);
  }

  if (data.alleleGenotypeB) {
    genotypeBPromise = $q.when(data.alleleGenotypeB);
  } else {
    genotypeBPromise =
      CursGenotypeList.storeGenotype(toaster, $http, undefined, undefined, undefined,
                                     [data.alleleB],
                                     undefined, undefined, undefined);
  }

  return $q.all([genotypeAPromise, genotypeBPromise])
    .then(function(result) {
      var alleleGenotypeA = result[0];
      var alleleGenotypeB = result[1];

      data.alleleGenotypeA = alleleGenotypeA;
      data.alleleGenotypeB = alleleGenotypeB;

      return data;
    });
}

var genotypeInteractionEditCtrl = function ($uibModal) {
  return {
    scope: {
      annotation: '=',
      annotationType: '<',
      genotypeInteractionInitialData: '<',
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/genotype_interaction_edit.html',
    controller: function ($scope) {
    },
    link: function ($scope) {

      $scope.editAnnotationInteractions = function() {
        var newInteractionsPromise =
            startInteractionAnnotationsEdit($uibModal, $scope.annotationType,
                                            $scope.genotypeInteractionInitialData);

        newInteractionsPromise.then(function(result) {
          if (result.genotype_a_phenotype_annotations.length == 0) {
            $scope.annotation.interaction_annotations.push(result);
          } else {
            $scope.annotation.interaction_annotations_with_phenotypes.push(result);
          }
        });
      };
    }
  };
};

canto.directive('genotypeInteractionEdit',
                ['$uibModal',
                 genotypeInteractionEditCtrl]);



function storeAnnotationToaster(AnnotationProxy, originalAnnotation,
                                editedAnnotation, toaster) {
  var q = AnnotationProxy.storeChanges(originalAnnotation,
                                       editedAnnotation, false);
  loadingStart();
  var storePop = toaster.pop({
    type: 'info',
    title: 'Storing annotation...',
    timeout: 0, // last until the finally()
    showCloseButton: false
  });
  q.then(function (annotation) {
    toaster.pop({
      type: 'success',
      title: 'Interaction stored successfully.',
      timeout: 4000,
      showCloseButton: true
    });
  })
    .catch(function (message) {
      toaster.pop('error', message);
    })
    .finally(function () {
      loadingEnd();
      toaster.clear(storePop);
    });

  return q;
}

var EditGenotypeInteractionDialogCtl =
  function ($scope, $uibModal, $uibModalInstance, toaster, AnnotationProxy, CantoGlobals, args) {
    $scope.annotationType = args.annotationType;
    $scope.genotypeInteractionInitialData = args.genotypeInteractionInitialData;

    $scope.editedAnnotation = {};

    copyObject(args.annotation, $scope.editedAnnotation);

    $scope.ok = function() {
      var q = storeAnnotationToaster(AnnotationProxy, args.annotation,
                                     $scope.editedAnnotation, toaster);

      q.then(function() {
        $uibModalInstance.close($scope.editedAnnotation);

        if (CantoGlobals.current_user_is_admin) {
          toaster.pop({type: 'warning',
                       title: 'Reload page to see changes',
                       timeout: 6000,
                       showCloseButton: false
                      });
        } else {
          setTimeout(function () {
            // hopefully temporary:
            window.location.reload();
          }, 600);
        }
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('EditGenotypeInteractionDialogCtl',
                 ['$scope', '$uibModal', '$uibModalInstance',
                  'toaster', 'AnnotationProxy', 'CantoGlobals', 'args',
                  EditGenotypeInteractionDialogCtl
                 ]);



function editGenotypeInteractions($uibModal, annotation, annotationType, genotypeInteractionInitialData) {
  var editInstance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/genotype_interaction_edit_dialog.html',
    controller: 'EditGenotypeInteractionDialogCtl',
    title: 'Edit message',
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          annotation: annotation,
          annotationType: annotationType,
          genotypeInteractionInitialData: genotypeInteractionInitialData,
        };
      }
    },
    backdrop: 'static',
  });

  return editInstance.result;
}



var annotationEditDialogCtrl =
  function ($scope, $uibModal, $q, $uibModalInstance, $http, AnnotationProxy,
            AnnotationTypeConfig, CantoConfig, CursGenotypeList, CursGeneList,
            CursSessionDetails, CantoService, CantoGlobals, Curs, toaster, args) {
    $scope.currentUserIsAdmin = CantoGlobals.current_user_is_admin;
    $scope.flyBaseMode = CantoGlobals.flybase_mode;
    $scope.showFigureField = CantoGlobals.annotationFigureField;
    $scope.app_static_path = CantoGlobals.app_static_path;
    $scope.annotation = {};
    $scope.annotationTypeName = args.annotationTypeName;
    $scope.annotationType = null;
    $scope.currentFeatureDisplayName = args.currentFeatureDisplayName;
    $scope.newlyAdded = args.newlyAdded;
    $scope.featureEditable = args.featureEditable;
    $scope.matchingConfigurations = [];
    $scope.termSuggestionVisible = false;
    $scope.featureSubtype = null;
    $scope.allowInteractionAnnotations = false;
    $scope.interactionsChanged = false;

    $scope.genotypeInteractionInitialData = null;

    if (args.annotation.term_suggestion_name ||
        args.annotation.term_suggestion_definition) {
      $scope.termSuggestionVisible = true;
    }

    $scope.status = {
      validEvidence: false,
      showEvidence: true,
    };
    $scope.chooseFeatureType = null;
    $scope.organisms = [];
    $scope.selectedOrganism = args.annotation.organism;
    $scope.selectedOrganismB = null;
    $scope.hideRelationNames = [];
    $scope.conditionsHelpText = null;

    $scope.multiOrganismMode = CantoGlobals.multi_organism_mode;

    $scope.initialSelectedOrganismId = null;
    $scope.initialSelectedOrganismBId = null;

    $scope.termNameConstraint = undefined;

    if (args.annotation.feature_a_taxonid) {
      $scope.initialSelectedOrganismId = args.annotation.feature_a_taxonid;
    }

    if (args.annotation.feature_b_taxonid) {
      $scope.initialSelectedOrganismBId = args.annotation.feature_b_taxonid;
    }

    if (args.annotation.organism) {
      $scope.selectedOrganism = args.annotation.organism.taxonid;
      if (!$scope.initialSelectedOrganismId) {
        $scope.initialSelectedOrganismId = args.annotation.organism.taxonid;
      }
      if (CantoGlobals.pathogen_host_mode) {
        $scope.featureSubtype = getFeatureSubtype(
          args.annotation.feature_type,
          args.annotation.organism
        );
      }
    }

    $scope.models = {
      chosenSuggestedTerm: null,
    };

    $scope.termSuggestions = [];
    $scope.isMetagenotypeAnnotation = null;

    if ($scope.annotation.interaction_type === undefined) {
      $scope.annotation.interaction_type = null;
    }

    copyObject(args.annotation, $scope.annotation);

    $scope.filteredFeatures = null;
    $scope.filteredFeaturesB = null;

    $scope.hasFigure = $scope.annotation.figure;

    // See: https://github.com/pombase/canto/issues/2540
    $scope.interactionAnnotationsChange = function(newCollection, oldCollection) {
      if (!newCollection || !oldCollection) {
        return;
      }
      if (newCollection.length != oldCollection.length) {
        $scope.interactionsChanged = true;
      }
      if ($scope.annotation.interaction_annotations &&
          $scope.annotation.interaction_annotations.length > 0 ||
          $scope.annotation.interaction_annotations_with_phenotypes &&
          $scope.annotation.interaction_annotations_with_phenotypes.length > 0) {
        $scope.featureEditable = false;
      } else {
        $scope.featureEditable = args.featureEditable;
      }
    };
    $scope.$watchCollection('annotation.interaction_annotations',
                            $scope.interactionAnnotationsChange);
    $scope.$watchCollection('annotation.interaction_annotations_with_phenotypes',
                            $scope.interactionAnnotationsChange);

    $scope.hasInteractions = function() {
      return $scope.annotation.interaction_annotations &&
        $scope.annotation.interaction_annotations.length > 0 ||
        $scope.annotation.interaction_annotations_with_phenotypes &&
        $scope.annotation.interaction_annotations_with_phenotypes.length > 0;
    };

    $scope.termEditable = function() {
      return !$scope.annotation.term_ontid || !$scope.hasInteractions();
    };

    $scope.showStrainName = (
      CantoGlobals.strains_mode &&
      $scope.annotation.strain_name
    );

    $scope.annotationTypePromise = AnnotationTypeConfig.getByName($scope.annotationTypeName);

    $scope.annotationTypePromise
      .then(annotationType => {
        if (annotationType.associated_interaction_annotation_type) {
          if (!$scope.annotation.interaction_annotations) {
            $scope.annotation.interaction_annotations = [];
          }
          if (!$scope.annotation.interaction_annotations_with_phenotypes) {
            $scope.annotation.interaction_annotations_with_phenotypes = [];
          }
        }
      });

    $scope.annotationTypePromise
      .then(function(annotationType) {
        $scope.termNameConstraint = args.termConstraint || annotationType.name;
      });

    $scope.alleleTypesPromise = CantoConfig.get('allele_types');
    $scope.organismPromise = Curs.list('organism', [{ include_counts: 1 }]);
    $scope.instanceOrganismPromise = CantoConfig.get('instance_organism');
    $scope.extConfigPromise = CantoConfig.get('extension_configuration');
    $scope.cursConfigPromise = CantoConfig.get('curs_config');

    // the term+extensions in these annotations will be used as term suggestions in
    // interaction annotations
    $scope.annotationsPromise = $scope.annotationTypePromise
      .then(function(annotationType) {
        if (annotationType.term_suggestions_annotation_type) {
          return AnnotationProxy.getAnnotation(annotationType.term_suggestions_annotation_type);
        } else {
          return [];
        }
      });

    $scope.cursConfigPromise.then(function(data) {
      var conditionsHelpText = data['experimental_conditions_help_text'];
      $scope.conditionsHelpText = conditionsHelpText;
    });

    $scope.allPromise = null;

    $scope.allPromise =
      $q.all([$scope.annotationTypePromise, $scope.alleleTypesPromise, $scope.organismPromise,
              $scope.instanceOrganismPromise, $scope.extConfigPromise]);


    $scope.filteredOrganismPromise =
      $scope.allPromise.then(function([annotationType, alleleTypes, organisms,
                                       instanceOrganism, extConfig]) {
        return $.grep(organisms,
                      function(organism) {
                        if (annotationType.feature_type == 'gene' &&
                           organism.genes.length == 0) {
                          return false;
                        }

                        if (annotationType.feature_type != 'gene' &&
                           organism.genotype_count == 0) {
                          return false;
                        }

                        if (!organism.full_name) {
                          return false;
                        }

                        if (!organism.taxonid) {
                          return false;
                        }

                        if (instanceOrganism.taxonid) {
                          return instanceOrganism.taxonid == organism.taxonid;
                        }

                        return true;
                      });
      });

    $scope.filteredOrganismPromise
      .then(function (organisms) {
        if (args.annotationTypeName === 'host_phenotype') {
          organisms = filterOrganisms(organisms, 'host');
        } else if (args.annotationTypeName === 'pathogen_phenotype') {
          organisms = filterOrganisms(organisms, 'pathogen');
        }
        if (organisms.length === 1) {
          $scope.selectedOrganism = organisms[0];
        } else {
          if (!$scope.featureEditable && args.annotation.organism) {
            $.map(organisms,
                  function(organism) {
                    if (organism.taxonid == args.annotation.organism.taxonid) {
                      $scope.selectedOrganism = organism;
                    }
                  });
          }
        }
        $scope.organisms = organisms;
        return organisms;
      })
      .then(function() {
        setFilteredFeatures();
        setFilteredFeaturesB();
      });


    $scope.filteredFeaturesDeferred = $q.defer();
    $scope.filteredFeaturesPromise = $scope.filteredFeaturesDeferred.promise;

    if (args.annotation.feature_id) {
      featureIdWatcher(args.annotation.feature_id);
    }

    $scope.annotationTypePromise
      .then(function (annotationType) {
        $scope.annotationType = annotationType;
        $scope.annotation.feature_type = annotationType.feature_type;

        $scope.hideRelationNames = annotationType.hide_extension_relations || [];

        if (annotationType.category === 'interaction') {
          if (annotationType.feature_type === 'gene') {
            $scope.chooseFeatureType = 'gene';

            $scope.annotation.second_feature_id = $scope.annotation.interacting_gene_id;
            delete $scope.annotation.interacting_gene_id;
          } else {
            $scope.chooseFeatureType = 'genotype';

            $scope.annotation.feature_id = $scope.annotation.genotype_a_id;
            delete $scope.annotation.genotype_a_id;
            $scope.annotation.second_feature_id = $scope.annotation.genotype_b_id;
            delete $scope.annotation.genotype_b_id;
          }
        } else {
          $scope.chooseFeatureType = annotationType.feature_type;
        }

        $scope.isMetagenotypeAnnotation =
          $scope.annotationType.feature_type == 'metagenotype' &&
          $scope.annotationType.category == 'ontology';

        $scope.displayAnnotationFeatureType = capitalizeFirstLetter($scope.chooseFeatureType);
        $scope.status.showEvidence = annotationType.evidence_codes.length > 0;

        if (annotationType.can_have_conditions &&
          !$scope.annotation['conditions']) {
          $scope.annotation.conditions = [];
        }

        if (!$scope.annotation['extension']) {
          $scope.annotation.extension = [];
        }
      });


    function filterFeatures (features, extraFilterFunc) {
      if ($scope.selectedOrganism) {
        $scope.alleleTypesPromise
          .then(function(alleleTypes) {
            $scope.filteredFeatures =
              $.grep(features,
                     function(feature) {
                       if (feature.organism.taxonid === $scope.selectedOrganism.taxonid) {
                         if (extraFilterFunc) {
                           return extraFilterFunc(feature, alleleTypes);
                         } else {
                           return true;
                         }
                       } else {
                         return false;
                       }
                     });
          });
      } else {
        $scope.filteredFeatures = features;
      }

      $scope.filteredFeaturesDeferred.resolve($scope.filteredFeatures);
    }

    function filterFeaturesB(features) {
      if ($scope.selectedOrganismB) {
        $scope.filteredFeaturesB =
          $.grep(features,
                 function(feature) {
                   return feature.organism.taxonid === $scope.selectedOrganismB.taxonid;
                 });
      } else {
        $scope.filteredFeaturesB = features;
      }

//  set the feature if there's only one possibilty:
//      if ($scope.filteredFeaturesB.length == 1) {
//        $scope.annotation.second_feature_id = $scope.filteredFeaturesB[0].feature_id;
//      }
    }

    function removeAccessoryAlleles(alleleTypes, alleles) {
      return $.grep(alleles,
                    function(allele) {
                      var alleleType = alleleTypes[allele.type];
                      return !alleleType || !alleleType.do_not_annotate;
                    });
    }

    // return aberrations / alleles with no gene
    function removeAberrationAlleles(alleles) {
      return $.grep(alleles,
                    function(allele) {
                      return !!allele.gene_id;
                    });
    }

    function setFilteredFeatures () {
      if ($scope.chooseFeatureType === 'gene') {
        if (!$scope.selectedOrganism) {
          return null;
        }

        CursGeneList.geneList().then(function (results) {
          filterFeatures(results);
        }).catch(function (err) {
          toaster.pop('note', "couldn't read the gene list from the server");
        });
      } else {
        if ($scope.chooseFeatureType === 'genotype') {
          if (!$scope.selectedOrganism) {
            return null;
          }

          CursGenotypeList.cursGenotypeList({ include_allele: 1 }).then(function (results) {
            $scope.annotationTypePromise.then(function (annotationType) {
              var filterFunc =
                function(feature, alleleTypes) {
                  var nonAccessoryAlleles =
                    removeAccessoryAlleles(alleleTypes, feature.alleles);

                  if (nonAccessoryAlleles.length == 0) {
                    return false;
                  }

                  if (annotationType.single_allele_only) {
                    if (annotationType.single_allele_only === 'ignore_accessory') {
                      return nonAccessoryAlleles.length == 1;
                    } else {
                      return feature.alleles.length == 1;
                    }
                  } else {
                    if (annotationType.single_locus_only) {
                      var seenGenes = [];
                      $.map(nonAccessoryAlleles,
                            function(allele) {
                              if (typeof (allele.gene_id) == 'undefined') {
                                // ignore aberrations
                                return;
                              }
                              if (seenGenes.indexOf(allele.gene_id) == -1) {
                                seenGenes.push(allele.gene_id);
                              }
                            });
                      return seenGenes.length == 1;
                    }

                    return true;
                  }
                };
              filterFeatures(results, filterFunc);

              $scope.allFeatures = results;

              $scope.filteredFeaturesB = $scope.filteredFeatures;
            });
          }).catch(function (err) {
            toaster.pop('note', "couldn't read the genotype list from the server");
          });
        } else {
          Curs.list('metagenotype').then(function (results) {
            filterFeatures(results);
          }).catch(function (err) {
            toaster.pop('note', "couldn't read the metagenotype list from the server");
          });
        }
      }
    }

    function setFilteredFeaturesB () {
      if (!$scope.annotationType.second_feature_organism_selector) {
        return;
      }

      if ($scope.chooseFeatureType === 'gene') {
        if (!$scope.selectedOrganismB) {
          return null;
        }

        CursGeneList.geneList().then(function (results) {
          filterFeaturesB(results);
        }).catch(function (err) {
          toaster.pop('note', "couldn't read the gene list from the server");
        });
      } else {
        console.error('second_feature_organism_selector config option not implemented for: ' +
                      $scope.chooseFeatureType);
      }
    }

    $scope.organismSelected = function (organism) {
      $scope.selectedOrganism = organism;
      if (CantoGlobals.pathogen_host_mode) {
        $scope.featureSubtype = getFeatureSubtype(
          $scope.annotation.feature_type,
          organism
        );
      }
      $scope.allPromise.then(function () {
        setFilteredFeatures();
      });
    };

    $scope.organismBSelected = function (organism) {
      $scope.selectedOrganismB = organism;
      $scope.allPromise.then(function () {
        setFilteredFeaturesB();
      });
    };

    $scope.openSingleGeneAddDialog = function () {
      var modal = openSingleGeneAddDialog($uibModal);
      modal.result.then(function () {
        $scope.allPromise.then(function () {
          setFilteredFeatures();
          setFilteredFeaturesB();
        });
      });
    };

    $scope.isValidOrganism = function () {
      return !!$scope.selectedOrganism;
    };

    $scope.isValidOrganismB = function () {
      return !!$scope.selectedOrganismB;
    };

    $scope.isValidFeature = function () {
      return $scope.annotation.feature_id;
    };

    $scope.validFeatures = function () {
      return $scope.isValidFeature() && $scope.annotation.second_feature_id;
    };

    $scope.isValidTerm = function () {
      if (!$scope.annotationType) {
        return false;
      }
      return ($scope.annotationType.category == 'interaction' &&
              !$scope.annotationType.interaction_term_required) ||
        $scope.annotation.term_ontid;
    };

    $scope.isValidEvidence = function () {
      if (!$scope.status.showEvidence) {
        return true;
      }
      return $scope.status.validEvidence;
    };

    $scope.showConditions = function () {
      return $scope.status.validEvidence &&
        $scope.annotationType && $scope.annotationType.can_have_conditions &&
        $scope.annotation.term_ontid;
    };

    // returns true if it's possible to show a suggestion field for this
    // annotation - although the field isn't shown until the user clicks
    // the "Suggest a term" link/button
    $scope.suggestionFieldsPossible = function() {
      return $scope.isValidTerm() && $scope.annotationType.category == 'ontology' &&
        $scope.annotationType.ontology_size !== 'small' &&
        $scope.filteredFeatures && $scope.filteredFeatures.length != 0;
    };

    $scope.setTermSuggestionVisible = function(newValue) {
      $scope.termSuggestionVisible = newValue;
    };

    $scope.annotationChanged = function () {
      var objectToStore = $scope.getObjectToStore();
      var changesToStore = {};
      copyIfChanged(args.annotation, objectToStore, changesToStore);
      delete changesToStore.feature_type;
      return countKeys(changesToStore) > 0;
    };

    $scope.featureChooserTitle = function() {
      if ($scope.featureEditable) {
        return 'Choose a ' + $scope.annotationType.feature_type;
      } else {
        return 'This annotation is not editable because it has associated genetic interactions';
      }
    };

    $scope.okButtonTitleMessage = function () {
      if ($scope.isValid()) {
        if ($scope.annotationChanged()) {
          return 'Finish editing';
        } else {
          return 'Make some changes or click "Cancel"';
        }
      } else {
        return 'Annotation is incomplete - please edit the fields marked in red';
      }
    };

    $scope.termSuggestionSelected = function(chosenSuggestedTerm) {
      $scope.annotation.term_ontid = chosenSuggestedTerm.term_ontid;
      $scope.annotation.term_name = chosenSuggestedTerm.term_name;
      $scope.annotation.extension = chosenSuggestedTerm.extension;
    };

    function updateTermSuggestions(selectedFeatureId) {
      $scope.termSuggestions = [];

      $scope.annotationsPromise
        .then(function (annotations) {
          $scope.termSuggestions =
            $.map($.grep(annotations,
                         function(annotation) {
                           return annotation.feature_id == selectedFeatureId;
                         }),
                  function(annotation) {
                    var displayString = annotation.term_name;
                    var hideExtensionRelations = false;
                    if ($scope.annotationType.hide_extension_relations) {
                      hideExtensionRelations = true;
                    }
                    var extension =
                      extensionAsString(annotation.extension, true, hideExtensionRelations);

                    if (extension) {
                      displayString += ' - ' + extension;
                    }

                    return {
                      display_string: displayString,
                      term_ontid: annotation.term_ontid,
                      term_name: annotation.term_name,
                      extension: annotation.extension,
                    };
                  });
        });
    }

    function getFeatureSubtype(featureType, organism) {
      if (organism) {
        if (featureType == 'gene') {
          var organismRole = organism.pathogen_or_host;
          return organismRole + '_gene';
        }
      }
      return null;
    }

    function setGenotypeInteractionData(featureId, annotationType) {
      if (!featureId ||
          !annotationType.associated_interaction_annotation_type ||
          !$scope.annotation.term_ontid || !$scope.allFeatures) {
        return;
      }

      $scope.genotypeInteractionInitialData = null;

      var interactionInitialDataPromise =
          getInteractionInitialData($q, CantoConfig,
                                    $scope.termDetailsPromise,
                                    annotationType, $scope.annotation.term_ontid,
                                    featureId, $scope.allFeatures);

      interactionInitialDataPromise
        .then(function(data) {
          return findGenotypesOfAlleles(data, $q, AnnotationProxy,
                                        annotationType,
                                        $scope.allFeatures);
        })
        .then(function(data) {
          return createMissingGenotypesOfAlleles(data, $q, $http, toaster,
                                                   CursGenotypeList);
        })
        .then(function(initialData) {
        if (initialData !== null) {
          $scope.allowInteractionAnnotations = true;
          if (!$scope.annotation.interaction_annotations) {
            $scope.annotation.interaction_annotations = [];
          }
          if (!$scope.annotation.interaction_annotations_with_phenotypes) {
            $scope.annotation.interaction_annotations_with_phenotypes = [];
          }

          $scope.genotypeInteractionInitialData = initialData;
        }
      });

    }

    function featureIdWatcher(featureId) {
      $q.all([$scope.annotationTypePromise, $scope.filteredFeaturesPromise])
        .then(function (data) {
          var annotationType = data[0];

          if (annotationType.second_feature_organism_selector) {
            return;
          }

          $scope.allowInteractionAnnotations = false;
          $scope.interactionGenotypeA = null;
          $scope.interactionGenotypeB = null;

          setGenotypeInteractionData(featureId, annotationType);

          if (featureId) {

            if (annotationType.term_suggestions_annotation_type) {
              updateTermSuggestions(featureId);
            }

            if (!annotationType.interaction_same_locus) {
              $scope.filteredFeaturesB = $scope.filteredFeatures;
              return;
            }

            var selectedFeatureA =
              ($.grep($scope.filteredFeatures,
                      function(testFeature) {
                        return testFeature.feature_id == featureId;
                      }))[0];

            $scope.filteredFeaturesB = [];

            $scope.alleleTypesPromise
              .then(function(alleleTypes) {

                var nonAccessoryAlleles =
                    removeAccessoryAlleles(alleleTypes,
                                           selectedFeatureA.alleles);

                var selectedFeatAlleles = removeAberrationAlleles(nonAccessoryAlleles);

                $scope.filteredFeaturesB =
                  $.grep($scope.filteredFeatures,
                         function (testFeature) {
                           if (selectedFeatureA.genotype_id ==
                               testFeature.genotype_id) {
                             return false;
                           }
                           var testFeatAlleles =
                               removeAccessoryAlleles(alleleTypes,
                                                      testFeature.alleles);

                           testFeatAlleles = removeAberrationAlleles(testFeatAlleles);

                           if (testFeatAlleles.length == 0) {
                             return false;
                           }

                           return testFeatAlleles[0].gene_id ==
                             selectedFeatAlleles[0].gene_id;
                         });
              });
          } else {
            $scope.filteredFeaturesB = null;
          }
        });
    }

    $scope.$watch('annotation.feature_id', featureIdWatcher);

    function termIdWatcher () {
      $scope.matchingConfigurations = [];

      if ($scope.annotation.term_ontid) {
        $scope.termDetailsPromise =
          CantoService.lookup('ontology', [$scope.annotation.term_ontid], {
            subset_ids: 1,
          });

        $scope.annotationTypePromise.then(function(annotationType) {
          setGenotypeInteractionData($scope.annotation.feature_id,
                                     annotationType);
        });

        $q.all([$scope.extConfigPromise, $scope.termDetailsPromise])
          .then(function (data) {
            var extensionConfiguration = data[0];
            var termDetails = data[1];
            var subset_ids = termDetails.subset_ids;
            var featureType = $scope.featureSubtype || $scope.annotation.feature_type;

            var hasExtensionsAndSubsets = (
              extensionConfiguration.length > 0 &&
              subset_ids &&
              subset_ids.length > 0
            );

            if (hasExtensionsAndSubsets) {
              $scope.matchingConfigurations = extensionConfFilter(
                extensionConfiguration,
                subset_ids,
                CantoGlobals.current_user_is_admin ? 'admin' : 'user',
                $scope.annotationTypeName,
                featureType,
              );
            } else {
              $scope.matchingConfigurations = [];
            }
          });
      }
    }

    $scope.$watch('annotation.term_ontid', termIdWatcher);

    $scope.isValid = function () {
      if (!$scope.annotationType) {
        return false;
      }

      if ($scope.annotationType.category === 'ontology') {
        return $scope.isValidFeature() &&
          $scope.isValidTerm() && $scope.isValidEvidence();
      }
      return $scope.validFeatures() && $scope.isValidEvidence();
    };

    $scope.termFoundCallback =
      function (termId, termName, searchString) {
        $scope.annotation.term_ontid = termId;
        $scope.annotation.term_name = termName;

        if (!termId) {
          // user has cleared the input field, so we clear the term_ontid and continue
          $scope.annotation.conditions = [];
          $scope.annotation.extension = [];
          return;
        }

        if (searchString && !searchString.match(/^".*"$/) && searchString !== termId) {
          var termConfirm = openTermConfirmDialog($uibModal, termId, 'definition',
            $scope.annotationType.feature_type, false);

          termConfirm.result.then(function (result) {
            $scope.annotation.term_ontid = result.newTermId;
            $scope.annotation.term_name = result.newTermName;
          });
        } // else: user pasted a term ID or user quoted the search - skip confirmation
      };

    $scope.editExtension = function () {
      var featureType = $scope.featureSubtype || $scope.annotation.feature_type;
      var editPromise = openExtensionBuilderDialog(
        $uibModal,
        $scope.annotation.extension,
        $scope.annotation.term_ontid,
        $scope.currentFeatureDisplayName,
        $scope.annotationTypeName,
        featureType
      );

      editPromise.then(function (result) {
        angular.copy(result.extension, $scope.annotation.extension);
      });
    };

    $scope.manualEdit = function () {
      var editPromise =
        openExtensionManualEditDialog($uibModal, $scope.annotation.extension, $scope.matchingConfigurations);

      editPromise.then(function (result) {
        $scope.annotation.extension = result.extension;
      });
    };

    $scope.getObjectToStore = function(annotation) {
      var objectToStore = {};
      copyObject($scope.annotation, objectToStore);

      if ($scope.annotationType.category === 'interaction') {
        if ($scope.annotationType.feature_type === 'gene') {
          objectToStore.interacting_gene_id = $scope.annotation.second_feature_id;
          delete objectToStore.second_feature_id;
          delete objectToStore.extension;
        } else {
          objectToStore.genotype_a_id = $scope.annotation.feature_id;
          delete objectToStore.feature_id;
          objectToStore.genotype_b_id = $scope.annotation.second_feature_id;
          delete objectToStore.second_feature_id;
        }
      }

      if ($scope.annotationType.evidence_codes.length == 0) {
        delete objectToStore.evidence_code;
      }

      return objectToStore;
    };

    $scope.ok = function () {
      var objectToStore = $scope.getObjectToStore();
      var q = AnnotationProxy.storeChanges(args.annotation,
        objectToStore, args.newlyAdded);
      loadingStart();
      var storePop = toaster.pop({
        type: 'info',
        title: 'Storing annotation...',
        timeout: 0, // last until the finally()
        showCloseButton: false
      });
      q.then(function (annotation) {
        if (annotation === 'EXISTING') {
          toaster.pop({
            type: 'info',
            title: 'Not storing: an identical annotation exists.',
            timeout: 10000,
            showCloseButton: true
          });
        } else {
          $uibModalInstance.close(annotation);
          toaster.pop({
            type: 'success',
            title: 'Annotation stored successfully.',
            timeout: 5000,
            showCloseButton: true
          });
        }
        })
        .catch(function (message) {
          if ($scope.annotationType.category === 'interaction') {
            $scope.annotation.feature_id = $scope.annotation.genotype_a_id;
            delete $scope.annotation.genotype_a_id;
            $scope.annotation.second_feature_id = $scope.annotation.genotype_b_id;
            delete $scope.annotation.genotype_b_id;
          }

          toaster.pop('error', message);
        })
        .finally(function () {
          loadingEnd();
          toaster.clear(storePop);

          if ($scope.interactionsChanged) {
            setTimeout(function () {
              // hopefully temporary:
              window.location.reload();
            }, 1000);
          }
        });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };

    CursSessionDetails.get()
      .then(function (sessionDetails) {
        $scope.curatorDetails = sessionDetails.curator;
      });

    CantoService.details('user')
      .then(function (user) {
        $scope.userDetails = user.details;
      });
  };

canto.controller('AnnotationEditDialogCtrl',
  ['$scope', '$uibModal', '$q', '$uibModalInstance', '$http', 'AnnotationProxy',
   'AnnotationTypeConfig', 'CantoConfig', 'CursGenotypeList', 'CursGeneList',
    'CursSessionDetails', 'CantoService',
    'CantoGlobals', 'Curs', 'toaster', 'args',
    annotationEditDialogCtrl
  ]);



var annotationTransferDialogCtrl =
  function ($scope, $uibModal, $uibModalInstance, $q,
            AnnotationProxy,
            AnnotationTypeConfig, CursGenotypeList, CursGeneList,
            CantoConfig, Curs, toaster, args) {
    $scope.currentFeatureDisplayName = args.currentFeatureDisplayName;
    $scope.annotation = args.annotation;
    $scope.annotationTypeName = args.annotation.annotation_type;
    $scope.annotationType = null;
    $scope.alleleTypes = null;
    $scope.featureType = null;
    $scope.otherFeatures = null;
    $scope.selectedFeatureIds = [];
    $scope.transferExtension = true;
    $scope.extensionAsString = extensionAsString($scope.annotation.extension, true, true);

    $scope.interactorAorB = null;

    $scope.chooseFeatureType = null;

    $scope.featureDisplayName =
      $scope.annotation.feature_display_name || $scope.annotation.feature_a_display_name;

    $scope.termAndExtension = function() {
      if ($scope.annotation.term_name) {
        if ($scope.extensionAsString && $scope.extensionAsString.length > 0 &&
            $scope.transferExtension) {
          return $scope.annotation.term_name + ' (' + $scope.extensionAsString + ')';
        } else {
          return $scope.annotation.term_name + ' (no extension)';
        }
      } else {
        return null;
      }
    };

    $scope.annotationTypePromise = AnnotationTypeConfig.getByName($scope.annotationTypeName);
    $scope.alleleTypesPromise = CantoConfig.get('allele_types');

    function filterFeatures() {
      return $.grep($scope.features, function(feature) {
        if ($scope.chooseFeatureType === 'genotype' && feature.alleles.length == 1) {
          var allele = feature.alleles[0];
          var alleleType = $scope.alleleTypes[allele['type']];
          if (alleleType && alleleType['do_not_annotate']) {
            return false;
          }
        }

        var featureIdField = null;

        if ($scope.annotationType.category === 'ontology' ||
            $scope.annotationType.category === 'interaction' &&
            $scope.annotationType.feature_type !== 'metagenotype') {
          if ($scope.annotationType.category !== 'interaction' ||
              $scope.interactorAorB === 'A') {
            featureIdField = 'feature_id';
          } else {
            featureIdField = 'interacting_gene_id';
          }
        } else {
          if ($scope.interactorAorB === 'A') {
            featureIdField = 'genotype_a_id';
          } else {
            featureIdField = 'genotype_b_id';
          }
        }

        return feature.feature_id != $scope.annotation[featureIdField];
      });
    }

    $scope.getGeneFeatures = function() {
      CursGeneList.geneList().then(function (features) {
        $scope.features = features;
        $scope.otherFeatures = filterFeatures();
      }).catch(function (err) {
        toaster.pop('note', "couldn't read the gene list from the server");
      });
    };

    $scope.openSingleGeneAddDialog = function () {
      var modal = openSingleGeneAddDialog($uibModal);
      modal.result.then(function () {
        $scope.getGeneFeatures();
      });
    };

    $scope.chooseInteractor = function(interactorAorB) {
      $scope.interactorAorB = interactorAorB;

      $scope.otherFeatures = filterFeatures();
    };

    $q.all([$scope.annotationTypePromise, $scope.alleleTypesPromise])
      .then(function (results) {
        var annotationType = results[0];

        $scope.alleleTypes = results[1];

        $scope.annotationType = annotationType;
        $scope.featureType = annotationType.feature_type;
        $scope.chooseFeatureType = annotationType.feature_type;

        if (annotationType.category === 'interaction' &&
            annotationType.feature_type !== 'gene') {
          $scope.chooseFeatureType = 'genotype';
        }

        if ($scope.chooseFeatureType === 'gene') {
          $scope.getGeneFeatures();
        } else {
          if ($scope.chooseFeatureType === 'genotype') {
            CursGenotypeList.cursGenotypeList({include_allele: 1})
              .then(function (features) {
                $scope.features = features;
                $scope.otherFeatures = filterFeatures();
              }).catch(function (err) {
                toaster.pop('note', "couldn't read the genotype list from the server");
              });
          } else {
            toaster.pop('error', "annotation transfer not available for this " +
                        "annotation type");
          }
        }
      });


    $scope.toggleExtensionTransfer = function() {
      $scope.transferExtension = !$scope.transferExtension;
    };

    $scope.hasExtension = function() {
      return $scope.extensionAsString && $scope.extensionAsString.length > 0;
    };

    $scope.canTransfer = function() {
      return $scope.selectedFeatureIds.length > 0;
    };

    $scope.ok = function () {
      var annotationCopy = {};
      copyObject($scope.annotation, annotationCopy);

      if (!$scope.transferExtension) {
        annotationCopy.extension = [];
      }

      if (annotationCopy.interaction_annotations) {
        annotationCopy.interaction_annotations = [];
      }

      if (annotationCopy.interaction_annotations_with_phenotypes) {
        annotationCopy.interaction_annotations_with_phenotypes = [];
      }

      let existingCount = 0;

      let promises = [];

      $.map($scope.selectedFeatureIds,
            function(newId) {
              let destFeature = undefined;

              if ($scope.annotationType.category === 'ontology' ||
                  $scope.annotationType.category === 'interaction' &&
                  $scope.annotationType.feature_type !== 'metagenotype') {
                if ($scope.annotationType.category !== 'interaction' ||
                   $scope.interactorAorB === 'A') {
                  annotationCopy.feature_id = newId;

                  destFeature =
                    ($.grep($scope.features,
                            feature => feature.feature_id === annotationCopy.feature_id))[0];


                } else {
                  annotationCopy.interacting_gene_id = newId;
                }
              } else {
                if ($scope.interactorAorB === 'A') {
                  annotationCopy.genotype_a_id = newId;
                } else {
                  annotationCopy.genotype_b_id = newId;
                }
              }

              loadingStart();
              var q = AnnotationProxy.newAnnotation(annotationCopy);

              promises.push(q);

              var storePop = toaster.pop({
                type: 'info',
                title: 'Storing annotation...',
                timeout: 0, // last until the finally()
                showCloseButton: false
              });

              q.then(function (statusOrAnnotation) {
                toaster.clear(storePop);
                if (statusOrAnnotation === 'EXISTING') {
                  existingCount++;

                  toaster.pop({
                    type: 'info',
                    title: 'Not storing new annotation for ' + destFeature.display_name +
                      ': an identical annotation exists',
                    timeout: 10000,
                    showCloseButton: true
                  });
                } else {
                  toaster.pop({
                    type: 'success',
                    title: 'Annotation stored successfully.',
                    timeout: 5000,
                    showCloseButton: true
                  });
                }
              })
              .catch(function (message) {
                toaster.clear(storePop);
                toaster.pop('error', message);
              })
              .finally(function () {
                loadingEnd();
                toaster.clear(storePop);
              });
            });

      $q.all(promises).then(function () {
        if (existingCount == 0) {
          $uibModalInstance.close();
        }
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('AnnotationTransferDialogCtrl',
  ['$scope', '$uibModal', '$uibModalInstance', '$q',
   'AnnotationProxy',
   'AnnotationTypeConfig', 'CursGenotypeList', 'CursGeneList',
   'CantoConfig', 'Curs', 'toaster', 'args',
    annotationTransferDialogCtrl
  ]);


var annotationTransferAllDialogCtrl =
  function ($scope, $timeout, $window, $uibModal, $uibModalInstance, $q,
            AnnotationProxy,
            AnnotationTypeConfig, CursGenotypeList, CursGeneList,
            CantoGlobals, Curs, toaster, args) {
    $scope.read_only_curs = CantoGlobals.read_only_curs;

    $scope.data = {};

    $scope.data.featureId = args.featureId;
    $scope.data.featureDisplayName = args.featureDisplayName;
    $scope.data.annotationType = args.annotationType;
    $scope.data.featureType = $scope.data.annotationType.feature_type;
    $scope.data.annotations = args.annotations;
    $scope.data.feature = null;
    $scope.data.allFeatures = null;
    $scope.data.otherFeatures = null;
    $scope.data.chosenDestFeatureId = null;
    $scope.data.selectedAnnotationIds = [];
    $scope.data.transferExtension = true;

    $scope.data.annotationsById = {};

    $.map($scope.data.annotations,
          function(annotation) {
            $scope.data.annotationsById[annotation.annotation_id] = annotation;
          });

    $scope.processFeatures = function() {
      $scope.data.otherFeatures = [];
      $.map($scope.data.allFeatures,
            function(feature) {
              if (feature.feature_id == $scope.data.featureId) {
                $scope.data.feature = feature;
              } else {
                $scope.data.otherFeatures.push(feature);
              }
            });
    };

    $scope.getGeneFeatures = function() {
      CursGeneList.geneList().then(function (features) {
        $scope.data.allFeatures = features;
        $scope.processFeatures();
      }).catch(function (err) {
        toaster.pop('note', "couldn't read the gene list from the server");
      });
    };

    $scope.openSingleGeneAddDialog = function () {
      var modal = openSingleGeneAddDialog($uibModal);
      modal.result.then(function () {
        $scope.getGeneFeatures();
      });
    };

    if ($scope.data.featureType === 'gene') {
      $scope.getGeneFeatures();
    } else {
      if ($scope.data.featureType === 'genotype') {
        CursGenotypeList.cursGenotypeList({include_allele: 1})
          .then(function (features) {
            $scope.data.allFeatures = features;
            $scope.processFeatures();
          }).catch(function (err) {
            toaster.pop('note', "couldn't read the genotype list from the server");
          });
      } else {
        toaster.pop('error', "annotation transfer not available for this " +
                    "annotation type");
      }
    }

    $scope.selectionChanged = function(annotationIds) {
      $scope.data.selectedAnnotationIds = annotationIds;
    };

    $scope.toggleExtensionTransfer = function() {
      $scope.data.transferExtension = !$scope.data.transferExtension;
    };

    $scope.canTransfer = function() {
      return $scope.data.chosenDestFeatureId && $scope.data.selectedAnnotationIds.length > 0;
    };

    $scope.okButtonTitleMessage = function() {
      return "Transfer";
    };

    $scope.ok = function () {
      if (CantoGlobals.read_only_curs) {
        return;
      }

      let existingCount = 0;

      let promises = [];

      $.map($scope.data.selectedAnnotationIds,
            function(sourceAnnotationId) {
              var sourceAnnotation = $scope.data.annotationsById[sourceAnnotationId];

              var annotationCopy = {};
              copyObject(sourceAnnotation, annotationCopy);

              if (!$scope.data.transferExtension) {
                annotationCopy.extension = [];
              }

              annotationCopy.interaction_annotations = [];
              annotationCopy.interaction_annotations_with_phenotypes = [];

              annotationCopy.feature_id = $scope.data.chosenDestFeatureId;
              loadingStart();
              var q = AnnotationProxy.newAnnotation(annotationCopy);

              promises.push(q);

              var storePop = toaster.pop({
                type: 'info',
                title: 'Storing annotation...',
                timeout: 0, // last until the finally()
                showCloseButton: false
              });

              q.then(function (statusOrAnnotation) {
                toaster.clear(storePop);
                if (statusOrAnnotation === 'EXISTING') {
                  existingCount++;
                  toaster.pop({
                    type: 'info',
                    title: 'Not storing annotation for "' + sourceAnnotation.term_name +
                      '", evidence code "' + sourceAnnotation.evidence_code +
                      '": an identical annotation exists',
                    timeout: 10000,
                    showCloseButton: true
                  });
                } else {
                  toaster.pop({
                    type: 'success',
                    title: 'Annotation stored successfully.',
                    timeout: 5000,
                    showCloseButton: true
                  });
                }
              })
              .catch(function (message) {
                toaster.clear(storePop);
                toaster.pop('error', message);
              });
            });

      $q.all(promises).then(function () {
        if (existingCount == 0) {
          $uibModalInstance.close();

          $timeout(function() {
            // give users time to see the messages
            const destFeatureUrl =
                  CantoGlobals.curs_root_uri + '/feature/' +
                  $scope.data.annotationType.feature_type +
                  '/view/' + $scope.data.chosenDestFeatureId;
            $window.location.href = destFeatureUrl;
          }, 500);
        }
      })
      .finally(function () {
        loadingEnd();
      });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('AnnotationTransferAllDialogCtrl',
  ['$scope', '$timeout', '$window', '$uibModal', '$uibModalInstance', '$q',
   'AnnotationProxy',
   'AnnotationTypeConfig', 'CursGenotypeList', 'CursGeneList',
   'CantoGlobals', 'Curs', 'toaster', 'args',
    annotationTransferAllDialogCtrl
  ]);


var annotationTransferAllInteractionDialogCtrl =
  function ($scope, $window, $uibModal, $uibModalInstance, $q,
            AnnotationProxy,
            AnnotationTypeConfig, CursGenotypeList, CursGeneList,
            CantoGlobals, Curs, toaster, args) {
    $scope.read_only_curs = CantoGlobals.read_only_curs;

    $scope.data = {};

    $scope.data.featureId = args.featureId;
    $scope.data.featureDisplayName = args.featureDisplayName;
    $scope.data.annotationType = args.annotationType;
    $scope.data.featureType = $scope.data.annotationType.feature_type;

    $scope.data.interactorType = 'genotype';
    if ($scope.data.featureType === 'gene') {
      $scope.data.interactorType = 'gene';
    }

    $scope.data.annotations = null;

    $scope.data.feature = null;
    $scope.data.allFeatures = null;
    $scope.data.otherFeatures = null;
    $scope.data.chosenDestFeatureId = '';
    $scope.data.chosenDestFeature = null;
    $scope.data.selectedAnnotationIds = [];
    $scope.data.transferExtension = true;

    $scope.data.annotationsById = {};

    $.map(args.annotations,
          function(annotation) {
            $scope.data.annotationsById[annotation.annotation_id] = annotation;
          });

    $scope.processFeatures = function() {
      $scope.data.otherFeatures = [];
      $.map($scope.data.allFeatures,
            function(feature) {
              if (feature.feature_id == $scope.data.featureId) {
                $scope.data.feature = feature;
              } else {
                $scope.data.otherFeatures.push(feature);
              }
            });
    };

    function replaceAnnotationFeature(existingAnnotation, newFeature) {
      var newAnnotation =
        makeNewAnnotation(existingAnnotation);

      if (existingAnnotation.feature_a_id == $scope.data.featureId) {
        if ($scope.data.annotationType.feature_type == 'gene') {
          newAnnotation.feature_id = newFeature.feature_id;
        } else {
          newAnnotation.genotype_a_id = newFeature.feature_id;
        }
        newAnnotation.feature_a_id = newFeature.feature_id;
        newAnnotation.feature_a_display_name = newFeature.display_name;
      }

      if (existingAnnotation.feature_b_id == $scope.data.featureId) {
        if ($scope.data.annotationType.feature_type == 'gene') {
          newAnnotation.interacting_gene_id = newFeature.feature_id;
        } else {
          newAnnotation.genotype_b_id = newFeature.feature_id;
        }
        newAnnotation.feature_b_id = newFeature.feature_id;
        newAnnotation.feature_b_display_name = newFeature.display_name;
      }

      return newAnnotation;
    }

    function chosenFeatureIdChangeHandler(newFeatureId) {
      if (!newFeatureId) {
        $scope.data.annotations = null;
        $scope.data.chosenDestFeature = null;
        return;
      }
      $scope.data.chosenDestFeature =
        ($.grep($scope.data.otherFeatures,
                function(feat) {
                  return feat.feature_id == $scope.data.chosenDestFeatureId;
                }))[0];
      $scope.data.annotations =
        $.map(args.annotations,
              function(annotation) {
                var replacedAnnotation =
                  replaceAnnotationFeature(annotation,
                                           $scope.data.chosenDestFeature);

                $scope.data.annotationsById[replacedAnnotation.annotation_id] =
                  replacedAnnotation;

                return replacedAnnotation;
              });
    }

    $scope.$watch('data.chosenDestFeatureId',
                  chosenFeatureIdChangeHandler);

    var listPromise =
        $scope.data.interactorType === 'gene' ?
        Curs.list('gene') :
        CursGenotypeList.cursGenotypeList({});

    listPromise.then(function (features) {
      $scope.data.allFeatures = features;
      $scope.processFeatures();
    }).catch(function () {
      toaster.pop('note', "couldn't read the " + $scope.data.interactorType +
                  " list from the server");
    });

    $scope.selectionChanged = function(annotationIds) {
      $scope.data.selectedAnnotationIds = annotationIds;
    };

    $scope.canTransfer = function() {
      return $scope.data.chosenDestFeatureId && $scope.data.selectedAnnotationIds.length > 0;
    };

    $scope.okButtonTitleMessage = function() {
      return "Transfer";
    };

    $scope.ok = function () {
      if (CantoGlobals.read_only_curs) {
        return;
      }

      $.map($scope.data.selectedAnnotationIds,
            function(annotationId) {
              var annotation = $scope.data.annotationsById[annotationId];

              loadingStart();
              var q = AnnotationProxy.newAnnotation(annotation);

              var storePop = toaster.pop({
                type: 'info',
                title: 'Storing annotation...',
                timeout: 0, // last until the finally()
                showCloseButton: false
              });
              q.then(function () {
                $uibModalInstance.close();
                toaster.pop({
                  type: 'success',
                  title: 'Annotation stored successfully.',
                  timeout: 5000,
                  showCloseButton: true
                });
                var destFeatureUrl =
                    CantoGlobals.curs_root_uri + '/feature/' +
                    $scope.data.interactorType +
                    '/view/' + $scope.data.chosenDestFeatureId;
                $window.location.href = destFeatureUrl;
              })
              .catch(function (message) {
                toaster.pop('error', message);
              })
              .finally(function () {
                loadingEnd();
                toaster.clear(storePop);
              });
            });
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('AnnotationTransferAllInteractionDialogCtrl',
  ['$scope', '$window', '$uibModal', '$uibModalInstance', '$q',
   'AnnotationProxy',
   'AnnotationTypeConfig', 'CursGenotypeList', 'CursGeneList',
   'CantoGlobals', 'Curs', 'toaster', 'args',
    annotationTransferAllInteractionDialogCtrl
  ]);


angular.module('cantoApp')
  .directive('ngAltEnter', function ($document) {
    return {
      scope: {
        ngAltEnter: "&"
      },
      link: function (scope) {
        var enterWatcher = function (event) {
          if (event.altKey && event.key == "Enter") {
            scope.ngAltEnter();
            scope.$apply();
            event.preventDefault();
          }
        };

        $document.bind("keydown keypress", enterWatcher);

        scope.$on("$destroy",
          function handleDestroyEvent() {
            $document.unbind("keydown keypress", enterWatcher);
          });
      }
    };
  });


// if termConstraint is undefined, allow all terms from the CV
// of annotationTypeName
// termConstraint should be on the form '[FYPO:0000003]'
function startEditing($uibModal, annotationTypeName, annotation,
                      currentFeatureDisplayName, newlyAdded, featureEditable,
                      termConstraint) {
  var editInstance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/annotation_edit.html',
    controller: 'AnnotationEditDialogCtrl',
    title: 'Edit this annotation',
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          annotation: annotation,
          annotationTypeName: annotationTypeName,
          currentFeatureDisplayName: currentFeatureDisplayName,
          newlyAdded: newlyAdded,
          featureEditable: featureEditable,
          termConstraint: termConstraint,
        };
      }
    },
    backdrop: 'static',
  });

  return editInstance.result;
}

function startTransfer($uibModal, annotation, currentFeatureDisplayName) {
  var transferInstance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/annotation_transfer.html',
    controller: 'AnnotationTransferDialogCtrl',
    title: 'Transfer annotation from: ' + currentFeatureDisplayName,
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          annotation: annotation,
          currentFeatureDisplayName: currentFeatureDisplayName,
        };
      }
    },
    backdrop: 'static',
  });

  return transferInstance.result;
}


function startTransferAll($uibModal, featureId, featureDisplayName,
                          annotationType, annotations) {

  var params = {
    title: 'Transfer annotations',
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          featureId: featureId,
          featureDisplayName: featureDisplayName,
          annotationType: annotationType,
          annotations: annotations
        };
      }
    },
    backdrop: 'static',
  };

  if (annotationType.category == 'interaction') {
    params.templateUrl =
      app_static_path + 'ng_templates/annotation_transfer_all_interaction.html';
    params.controller =
      'AnnotationTransferAllInteractionDialogCtrl';
  } else {
    params.templateUrl =
      app_static_path + 'ng_templates/annotation_transfer_all.html';
    params.controller = 'AnnotationTransferAllDialogCtrl';
  }

  var transferInstance = $uibModal.open(params);

  return transferInstance.result;
}


function makeNewAnnotation(template) {
  var copy = {};
  copyObject(template, copy);
  copy.newly_added = true;
  return copy;
}


function addAnnotation($uibModal, annotationTypeName, featureType, featureId,
                       featureDisplayName, featureTaxonId, termConstraint) {
  var template = {
    annotation_type: annotationTypeName,
    feature_type: featureType,
  };
  if (featureId) {
    template.feature_id = Number(featureId);
  }
  if (featureTaxonId) {
    template.organism = {
      taxonid: featureTaxonId
    };
  }

  var featureEditable = !featureId;
  var newAnnotation = makeNewAnnotation(template);
  return startEditing($uibModal, annotationTypeName, newAnnotation,
                      featureDisplayName, true, featureEditable, termConstraint);
}

var annotationQuickAdd =
  function ($uibModal, CantoGlobals, CursGenotypeList) {
    return {
      scope: {
        annotationTypeName: '@',
        featureType: '@',
        featureId: '@',
        featureDisplayName: '@',
        featureTaxonId: '@',
        linkLabel: '@?'
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_quick_add.html',
      controller: function ($scope) {
        $scope.read_only_curs = CantoGlobals.read_only_curs;

        if (!$scope.linkLabel) {
          $scope.linkLabel = 'Quick add';
        }

        $scope.genotypeCount = null;

        if ($scope.featureType === 'metagenotype') {
          CursGenotypeList.cursGenotypeList({})
            .then(function (results) {
              if (results) {
                $scope.genotypeCount = results.length;
              } else {
                $scope.genotypeCount = null;
              }
            });
        }

        $scope.add = function () {
          if ($scope.featureType === 'metagenotype' &&
              (!$scope.genotypeCount || $scope.genotypeCount == 0)) {
            openSimpleDialog($uibModal, 'Interaction warning',
                             'Interaction warning',
                             "No genotypes have been curated yet so interaction annotations " +
                             "aren't possible.\n" +
                             'Add genotypes using the "Genotype management ..." link.');
            return;
          }

          addAnnotation($uibModal, $scope.annotationTypeName, $scope.featureType,
                        $scope.featureId, $scope.featureDisplayName, $scope.featureTaxonId,
                        undefined);
        };
      },
    };
  };

canto.directive('annotationQuickAdd', ['$uibModal', 'CantoGlobals', 'CursGenotypeList',
                                       annotationQuickAdd]);


function filterAnnotations(annotations, params) {
  return annotations.filter(function (annotation) {
    if (annotation.feature_type == 'genotype' && params.alleleCount && annotation.alleles != undefined) {
      if (params.alleleCount == 'single' && annotation.alleles.length != 1) {
        return false;
      }
      if (params.alleleCount == 'multi' && annotation.alleles.length == 1) {
        return false;
      }
    }

    if (!params.featureStatus ||
      annotation.status === params.featureStatus) {
      if (!params.featureId) {
        return true;
      }
      if (params.featureType) {
        if (params.featureType === 'gene') {
          if (annotation.gene_id == params.featureId) {
            return true;
          }
          if (typeof (annotation.interacting_gene_id) !== 'undefined' &&
            annotation.interacting_gene_id == params.featureId) {
            return true;
          }
          if (annotation.genotype_a_gene_ids &&
              $.grep(annotation.genotype_a_gene_ids,
                     function(geneId) {
                       return geneId == params.featureId;
                     }).length > 0) {
            return true;
          }
          if (annotation.genotype_b_gene_ids &&
              $.grep(annotation.genotype_b_gene_ids,
                     function(geneId) {
                       return geneId == params.featureId;
                     }).length > 0) {
            return true;
          }
          if (annotation.alleles !== undefined &&
            $.grep(annotation.alleles,
              function (alleleData) {
                return alleleData.gene_id.toString() === params.featureId;
              }).length > 0) {
            return true;
          }
        }
        if (params.featureType === 'genotype' &&
            (annotation.genotype_id == params.featureId ||
             annotation.double_mutant_genotype_id == params.featureId ||
             annotation.genotype_a_id == params.featureId ||
             annotation.genotype_b_id == params.featureId)) {
          return true;
        }
        if (params.featureType === 'metagenotype' &&
          annotation.metagenotype_id == params.featureId) {
          return true;
        }
      }
    }
    return false;
  });
}

function setHideColumns(annotation, hideColumns) {
  $.map(initialHideColumns,
        function (prop, key) {
          if (key == 'qualifiers' && annotation.is_not) {
            hideColumns[key] = false;
          }
          if (key == 'term_suggestion') {
            if (annotation.term_suggestion_name || annotation.term_suggestion_definition) {
              hideColumns[key] = false;
            }
          }
          if (annotation[key] &&
              (!$.isArray(annotation[key]) || annotation[key].length > 0 &&
               (!$.isArray(annotation[key][0]) || annotation[key][0].length > 0))) {
            hideColumns[key] = false;
          }
        });
}

var annotationTableCtrl =
  function ($timeout, $q, CantoGlobals, AnnotationTypeConfig, CursGenotypeList,
            CursSessionDetails, CantoConfig) {
    return {
      scope: {
        annotationTypeName: '@',
        annotations: '=',
        featureStatusFilter: '@',
        alleleCountFilter: '@',
        showMetagenotypeLink: '<',
        showCheckboxes: '<',
        checkboxesChanged: '&?',
        showSelectAll: '<',
        showMenu: '<',
        showFeatures: '<',
        highlightFeatureId: '<',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_table.html',
      controller: function ($scope) {
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.curs_session_state = CantoGlobals.curs_session_state;
        $scope.flyBaseMode = CantoGlobals.flybase_mode;

        $scope.isActiveSession = isActiveSession($scope.curs_session_state);

        $scope.multiOrganismMode = false;
        $scope.strainsMode = CantoGlobals.strains_mode;

        $scope.showInteractionTermColumns = false;

        $scope.checkboxesChecked = [];

        $scope.selectAllModel = false;

        // default is no sorting
        $scope.sortColumn = null;
        $scope.prevSortColumn = null;

        $scope.data = {
          sortedAnnotations: null,
          hideColumns: {},
          publicationUniquename: null,
          interactionAnnotations: [],
          interactionAnnotationsWithPhenotypes: [],
          interactionPhenotypeType: null,
        };

        $scope.checkboxChanged = function(annotationId, checkboxChecked) {
          if ($scope.showCheckboxes && $scope.checkboxesChanged !== undefined) {
            var idx = $scope.checkboxesChecked.indexOf(annotationId);

            if (idx !== -1 && !checkboxChecked) {
              $scope.checkboxesChecked.splice(idx, 1);
            }

            if (idx === -1 && checkboxChecked) {
              $scope.checkboxesChecked.push(annotationId);
            }

            $scope.checkboxesChanged({annotationIds: $scope.checkboxesChecked});
          }
        };

        $scope.selectAll = function() {
          $scope.selectAllModel = true;
          // very dodgy:
          $timeout(function() {
            // we need to reset the model after the rows have finished calling
            // checkboxChanged()
            $scope.selectAllModel = false;
          }, 1);
        };

        $scope.annotationTypeConfigPromise =
          AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function(annotationType) {
            $scope.annotationType = annotationType;

            var interactionPhenotypeTypeName =
                $scope.annotationType.associated_phenotype_annotation_type;
            if (interactionPhenotypeTypeName) {
              AnnotationTypeConfig.getByName(interactionPhenotypeTypeName)
                .then(function(annotationType) {
                  $scope.data.interactionPhenotypeType = annotationType;
                });
            }

            return annotationType;
          });

        var baseSortFunc =
            function(a, b, isCurrent) {
              function getColumnValue(annotation, columnName) {
                if (columnName === 'extension') {
                  var extString = extensionAsString(annotation[columnName], true, false);
                  if (extString) {
                    return extString.toLowerCase();
                  } else {
                    // null for empty strings so they are sorted last
                    return null;
                  }
                } else {
                  if (annotation[columnName]) {
                    if (columnName == 'feature_display_name' &&
                       annotation.feature_type == 'genotype') {
                      return $.map(getDisplayLoci(annotation.alleles),
                                   function(locus) {
                                     if (locus.long_display_name) {
                                       return locus.long_display_name.toLowerCase();
                                     } else {
                                       return "[null]";
                                     }
                                   }).join(' ');
                    } else {
                      return annotation[columnName].toLowerCase();
                    }
                  } else {
                    if (columnName == 'genotype_genes' &&
                        annotation.feature_type == 'genotype') {
                      return $.map(annotation.alleles,
                                   function(allele) {
                                     if (allele.gene_display_name) {
                                       return allele.gene_display_name.toLowerCase();
                                     } else {
                                       return "[null]";
                                     }
                                   }).join(' ');
                    } else {
                      if (columnName === 'organism_full_name' && annotation.organism) {
                        return annotation.organism.full_name;
                      } else {
                        return null;
                      }
                    }
                  }
                }
              }
              var column;
              if (isCurrent || !$scope.prevSortColumn) {
                column = $scope.sortColumn;
              } else {
                column = $scope.prevSortColumn;
              }
              var aVal = getColumnValue(a, column);
              if (!aVal) {
                return 1;
              } else {
                var bVal = getColumnValue(b, column);
                if (!bVal) {
                  return -1;
                } else {
                  if (aVal < bVal) {
                    return -1;
                  }
                  if (aVal > bVal) {
                    return 1;
                  }
                  if (isCurrent && $scope.prevSortColumn) {
                    // sort by the previous sort column as a tie-breaker
                    return baseSortFunc(a, b, false);
                  }
                }
              }
            };

        $scope.sortAnnotations =
          function() {
            if ($scope.annotations) {
              if ($scope.sortColumn) {
                $scope.data.sortedAnnotations = $scope.annotations.slice();
                $scope.data.sortedAnnotations.sort(function(a, b) {
                  return baseSortFunc(a, b, true);
                });
              } else {
                $scope.data.sortedAnnotations = $scope.annotations;
              }
            }
          };

        $scope.sortAnnotations();

        $scope.processGenotypeInteractions =
          function(annotationType) {
            if (annotationType.category !== 'genotype_interaction') {
              return;
            }

            $scope.$watch('annotations',
                          function() {
                            $.map($scope.annotations,
                                  function(annotation) {
                                    if (annotation.genotype_a_phenotype_annotations) {
                                      $scope.data.interactionAnnotationsWithPhenotypes.push(annotation);
                                    } else {
                                      $scope.data.interactionAnnotations.push(annotation);
                                    }
                                  });
                          });
          };

        $scope.setSortBy = function(col) {
          if ($scope.sortColumn === col) {
            $scope.setDefaultSort();
          } else {
            $scope.prevSortColumn = $scope.sortColumn;
            $scope.sortColumn = col;
            $scope.sortAnnotations();
          }
        };

        $scope.setDefaultSort = function() {
          $scope.sortColumn = null;
          $scope.sortAnnotations();
        };

        $scope.$watch('annotations',
          function () {
            if ($scope.annotations) {
              $scope.updateColumns();
              $scope.sortAnnotations();
              $scope.annotationTypeConfigPromise.then(function (annotationType) {
                $scope.processGenotypeInteractions(annotationType);
              });
            }
          },
          true);

        CursSessionDetails.get()
          .then(function (sessionDetails) {
            $scope.data.publicationUniquename = sessionDetails.publication_uniquename;
          });

        CantoConfig.get('instance_organism').then(function (results) {
          if (!results.taxonid) {
            $scope.multiOrganismMode = true;
          }
        });

        copyObject(initialHideColumns, $scope.data.hideColumns);

        $scope.updateColumns = function () {
          if ($scope.annotations) {
            copyObject(initialHideColumns, $scope.data.hideColumns);
            $.map($scope.annotations,
              function (annotation) {
                setHideColumns(annotation, $scope.data.hideColumns);
              });
          }

          // special case for curator column
          if ($scope.isActiveSession) {
            $scope.data.hideColumns['curator'] = true;
          }

          if ($scope.annotationType &&
              $scope.annotationType.annotation_table_columns_to_hide) {
            // force some columns to be hidden even if they aren't empty
            $.map($scope.annotationType.annotation_table_columns_to_hide,
                  function(columnName) {
                    $scope.data.hideColumns[columnName] = true;
                  });
          }
        };

        $scope.annotationTypeConfigPromise.then(function (annotationType) {
          $scope.updateColumns();
        });
      },
      link: function ($scope) {
        $scope.$watch('annotations.length',
          function () {
            $scope.annotationTypeConfigPromise
              .then(function (annotationType) {
                $scope.displayAnnotationFeatureType = capitalizeFirstLetter(annotationType.feature_type);
                if (annotationType.category == 'interaction') {
                  $scope.showInteractionTermColumns = !!annotationType.namespace;
                }
              });
          });


        // used by annotationTableRow code, create here so we don't re-fetch the
        // genotypes in every row
        $scope.genotypesPromiseForInteractions =
          $scope.annotationTypeConfigPromise.then(function (annotationType) {
            if (typeof(annotationType.associated_interaction_annotation_type) !== 'undefined'  &&
                $scope.alleleCountFilter == 'multi') {
              return CursGenotypeList.cursGenotypeList({
                include_allele: 1
              });
            } else {
              return $q.when([]);
            }
        });
      }
    };
  };

canto.directive('annotationTable',
   ['$timeout', '$q', 'CantoGlobals',
    'AnnotationTypeConfig', 'CursGenotypeList', 'CursSessionDetails', 'CantoConfig',
    annotationTableCtrl
  ]);


var annotationTableList =
  function ($uibModal, AnnotationProxy, AnnotationTypeConfig, CantoGlobals) {
    return {
      scope: {
        featureIdFilter: '@',
        featureTypeFilter: '@',
        featureFilterDisplayName: '@',
        showMetagenotypeLink: '<?'
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_table_list.html',
      controller: function ($scope) {
        $scope.countKeys = countKeys;
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.annotationTypes = [];
        $scope.annotationsByType = {};
        $scope.serverErrorsByType = {};
        $scope.byTypeSplit = {};
        $scope.showMetagenotypeLink = $scope.showMetagenotypeLink || false;

        $scope.capitalizeFirstLetter = capitalizeFirstLetter;
        $scope.data = {};

        $scope.watchAndFilter =
          function (annotations, annotationType) {
            function doFilter(annotations, featureStatusFilter, alleleCountFilter) {
              var params = {
                featureId: $scope.featureIdFilter,
                featureType: $scope.featureTypeFilter,
                featureStatus: featureStatusFilter,
                alleleCount: alleleCountFilter,
              };
              var key = featureStatusFilter;
              var filteredAnnotations = filterAnnotations(annotations, params);
              if (filteredAnnotations.length > 0) {
                if (typeof (alleleCountFilter) != 'undefined') {
                  if (typeof ($scope.byTypeSplit[annotationType.name][key]) == 'undefined') {
                    $scope.byTypeSplit[annotationType.name][key] = {};
                  }
                  $scope.byTypeSplit[annotationType.name][key][alleleCountFilter] =
                    filteredAnnotations;
                } else {
                  $scope.byTypeSplit[annotationType.name][key] =
                    filteredAnnotations;
                }
              }
            }

            $scope.$watch('annotationsByType["' + annotationType.name + '"]',
              function (annotations) {

                $scope.byTypeSplit[annotationType.name] = {};

                if (annotationType.feature_type == 'genotype' &&
                    annotationType.category != 'genotype_interaction') {
                  doFilter(annotations, 'new', 'single');
                  doFilter(annotations, 'new', 'multi');
                  doFilter(annotations, 'existing', 'single');
                  doFilter(annotations, 'existing', 'multi');
                } else {
                  doFilter(annotations, 'new');
                  doFilter(annotations, 'existing');
                }
              },
              true);
          };

        AnnotationTypeConfig.getAll().then(function (data) {
          $scope.annotationTypes =
            $.grep(data,
              function (annotationType) {
                if ($scope.featureTypeFilter === undefined ||
                  $scope.featureTypeFilter === 'gene' ||
                  annotationType.feature_type === $scope.featureTypeFilter ||
                  (annotationType.category === 'interaction' &&
                   $scope.featureTypeFilter === 'genotype')) {
                  return annotationType;
                }
              });

          $.map($scope.annotationTypes,
            function (annotationType) {
              AnnotationProxy.getAnnotation(annotationType.name)
                .then(function (annotations) {
                  $scope.annotationsByType[annotationType.name] = annotations;
                  $scope.watchAndFilter(annotations, annotationType);
                }).catch(function () {
                  $scope.serverErrorsByType[annotationType.name] =
                    "couldn't read annotations from the server - please try reloading";
                });
            });
        }).catch(function (response) {
          if (response.status) {
            $scope.data.serverError = "couldn't read annotation types from the server ";
          } // otherwise the request was cancelled
        });

        $scope.canTransfer = function(annotationType) {
          return CantoGlobals.is_admin_user &&
            !CantoGlobals.read_only_curs && $scope.featureIdFilter &&
            (annotationType.category  == 'ontology' &&
             annotationType.feature_type != 'metagenotype' ||
             annotationType.category == 'interaction');
        };

        $scope.filterAnnotationsForTransfer = function(annotationType) {
          var params = {
            featureId: $scope.featureIdFilter,
            featureType: $scope.featureTypeFilter,
            featureStatus: 'new',
            alleleCount: undefined,
          };

          return filterAnnotations($scope.annotationsByType[annotationType.name], params);
        };

        $scope.transferAll = function(annotationType) {
          var annotationsToTransfer = $scope.filterAnnotationsForTransfer(annotationType);

          startTransferAll($uibModal, $scope.featureIdFilter,
                           $scope.featureFilterDisplayName,
                           annotationType, annotationsToTransfer);
        };
      },
    };
  };

canto.directive('annotationTableList',
                ['$uibModal', 'AnnotationProxy', 'AnnotationTypeConfig', 'CantoGlobals',
                 annotationTableList]);


var annotationTableRow =
    function ($uibModal, $q, $http, CursGenotypeList,
              CursSessionDetails, CursAnnotationDataService,
              AnnotationProxy, AnnotationTypeConfig, CantoGlobals,
              CantoConfig, CantoService, toaster) {
    return {
      restrict: 'A',
      replace: true,
      templateUrl: function (elem, attrs) {
        return app_static_path + 'ng_templates/annotation_table_' +
          attrs.annotationTypeName + '_row.html';
      },
      controller: function ($scope, $element, $attrs) {
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.multiOrganismMode = false;
        $scope.showStrain = false;
        $scope.annotationType = null;
        $scope.sessionState = 'UNKNOWN';
        $scope.hideRelationNames = [];
        $scope.featureType = null;
        $scope.interactionFeatureType = null;
        $scope.showInteractionTermColumns = false;
        $scope.hasWildTypeHost = false;
        $scope.showTransferLink = false;
        $scope.showEditLink = false;
        $scope.isMetagenotypeAnnotation = false;
        $scope.checkboxChecked = false;
        $scope.genotypeInteractionInitialData = null;
        $scope.editInProgress = false;

        CursSessionDetails.get()
          .then(function (sessionDetails) {
            $scope.sessionState = sessionDetails.state;
          });

        // from the parent scope:
        var annotation = $scope.annotation;

        $scope.isMetagenotypeAnnotation = (
          $scope.annotation.feature_type === 'metagenotype'
        );

        $scope.$watchCollection('annotation.alleles',
                                function(newAlleles) {
                                  if (newAlleles) {
                                    $scope.displayLoci = getDisplayLoci(newAlleles);
                                  } else {
                                    $scope.displayLoci = null;
                                  }
                                });

        $scope.checked = annotation['checked'] || 'no';

        $scope.setChecked = function ($event) {
          CursAnnotationDataService.set(annotation.annotation_id,
              'checked', 'yes')
            .then(function () {
              $scope.checked = 'yes';
            });
          $event.preventDefault();
        };

        $scope.clearChecked = function ($event) {
          CursAnnotationDataService.set(annotation.annotation_id,
              'checked', 'no')
            .then(function () {
              $scope.checked = 'no';
            });
          $event.preventDefault();
        };

        $scope.displayEvidence = annotation.evidence_code;

        function checkboxCallback() {
          if ($scope.showCheckboxes && $scope.checkboxChanged !== undefined) {
            $scope.checkboxChanged(annotation.annotation_id,
                                   $scope.checkboxChecked);
          }
        }

        $scope.checkboxClick = function() {
          $scope.checkboxChecked = !$scope.checkboxChecked;
          checkboxCallback();
        };

        // FIXME: this very dodgy because "selectAllModel" is from the parent scope
        $scope.$watch('selectAllModel',
                      function(newValue) {
                        if (newValue) {
                          $scope.checkboxChecked = true;
                          checkboxCallback();
                        }
                      });

        $scope.hasWildTypeHost = (
          $scope.annotation.feature_type == 'metagenotype' &&
          CantoGlobals.pathogen_host_mode &&
          isWildTypeGenotype($scope.annotation.host_genotype)
        );

        if (typeof ($scope.annotation.conditions) !== 'undefined') {
          $scope.annotation.conditionsString =
            conditionsToStringHighlightNew($scope.annotation.conditions);
        }

        var qualifiersList = [];

        if (typeof ($scope.annotation.qualifiers) !== 'undefined' && $scope.annotation.qualifiers !== null) {
          qualifiersList = $scope.annotation.qualifiers;
        }

        if ($scope.annotation.is_not) {
          qualifiersList.unshift('NOT');
        }

        $scope.annotation.qualifiersString = qualifiersList.join(', ');

        var annotationTypePromise =
          AnnotationTypeConfig.getByName(annotation.annotation_type);
        annotationTypePromise
          .then(function (annotationType) {
            $scope.annotationType = annotationType;
            $scope.featureType = annotationType.feature_type;
            $scope.hideRelationNames = annotationType.hide_extension_relations || [];
            $scope.showStrain =
              $scope.strainsMode && $scope.annotationType.feature_type == 'genotype';
            if (annotationType.category == 'interaction') {
              $scope.showInteractionTermColumns = !!annotationType.namespace;
              if (annotationType.feature_type == 'gene') {
                $scope.interactionFeatureType = 'gene';
              } else {
                $scope.interactionFeatureType = 'genotype';
              }
            }
            $scope.showEditLink = !annotationType.delete_only;
            $scope.showTransferLink =
              !annotationType.delete_only && (
              (annotationType.allow_annotation_transfer ||
               CantoGlobals.is_admin_user) &&
              !(annotationType.category == 'ontology' &&
                annotationType.feature_type === 'metagenotype'));
          });

        CantoConfig.get('instance_organism').then(function (results) {
          if (!results.taxonid) {
            $scope.multiOrganismMode = true;
          }
        });

        $scope.$watch('annotation.evidence_code',
          function (newEvidenceCode) {
            if (newEvidenceCode) {
              CantoConfig.get('evidence_types').then(function (results) {
                $scope.evidenceTypes = results;

                annotationTypePromise.then(function () {
                  if (results[newEvidenceCode]) {
                    $scope.displayEvidence = results[newEvidenceCode].name;
                  } else {
                    $scope.displayEvidence = newEvidenceCode;
                  }
                });
              });
            } else {
              $scope.displayEvidence = '';
            }
          });

        $scope.addLinks = function () {
          return !CantoGlobals.read_only_curs &&
            ($scope.showMenu === undefined || $scope.showMenu) &&
            $attrs.featureStatusFilter == 'new';
        };

        $scope.isMetagenotypeLinkEnabled = function () {
          return $attrs.showMetagenotypeLink == 'true';
        };

        $scope.featureLink = function (featureType, featureId) {
          return $scope.curs_root_uri + '/feature/' +
            featureType + '/view/' +
            featureId + ($scope.read_only_curs ? '/ro' : '');
        };

        $scope.edit = function () {
          // FIXME: featureFilterDisplayName is from the parent scope
          var editPromise =
            startEditing($uibModal, annotation.annotation_type, $scope.annotation,
              $scope.featureFilterDisplayName, false, true);

          editPromise.then(function (editedAnnotation) {
            $scope.annotation = editedAnnotation;
            $scope.updateInteractionInitialData();
            if (typeof ($scope.annotation.conditions) !== 'undefined') {
              $scope.annotation.conditionsString =
                conditionsToStringHighlightNew($scope.annotation.conditions);
            }
          });
        };

        $scope.interactionViewLinkVisible = function() {
          return $scope.genotypeInteractionInitialData &&
            annotation.status !== 'existing' &&
            !$scope.read_only_curs;
        };

        $scope.updateInteractionInitialData = function(genotypesPromise) {
          if (!genotypesPromise) {
            genotypesPromise = CursGenotypeList.cursGenotypeList({
              include_allele: 1
            });
          }

          return $q.all([annotationTypePromise, genotypesPromise])
           .then(function(results) {
            var annotationType = results[0];
            var genotypes = results[1];

            if (annotationType.associated_interaction_annotation_type) {
              var termDetailsPromise =
                  CantoService.lookup('ontology',
                                      [$scope.annotation.term_ontid], {
                  subset_ids: 1,
                                      });

              var interactionInitialDataPromise =
                  getInteractionInitialData($q, CantoConfig,
                                            termDetailsPromise,
                                            annotationType, $scope.annotation.term_ontid,
                                            $scope.annotation.feature_id, genotypes);

            return interactionInitialDataPromise
                .then(function(data) {
                  return findGenotypesOfAlleles(data, $q, AnnotationProxy,
                                                annotationType,
                                                genotypes);
                })
                .then(function(data) {
                  return createMissingGenotypesOfAlleles(data, $q, $http, toaster,
                                                         CursGenotypeList);
                })
                .then(function(initialData) {
                if (initialData !== null) {
                  if (!$scope.annotation.interaction_annotations) {
                    $scope.annotation.interaction_annotations = [];
                  }
                  if (!$scope.annotation.interaction_annotations_with_phenotypes) {
                    $scope.annotation.interaction_annotations_with_phenotypes = [];
                  }

                  return initialData;
                } else {
                  return null;
                }
              });
            }

            return null;
          });
        };

        $scope.updateInteractionInitialData($scope.genotypesPromiseForInteractions)
          .then((initialData) => {
            $scope.genotypeInteractionInitialData = initialData;
          });

        $scope.viewEditInteractions = function() {
          if ($scope.editInProgress) {
            return;
          }
          $scope.editInProgress = true;
          annotationTypePromise.then(function(annotationType) {
            var interactionInitialDataPromise =
                $scope.updateInteractionInitialData(null);

            interactionInitialDataPromise.then((initialData) => {

            if ($scope.genotypeInteractionCount() == 0) {
              var editedAnnotation = {};

              copyObject($scope.annotation, editedAnnotation);

              var newInteractionsPromise =
                  startInteractionAnnotationsEdit($uibModal, annotationType,
                                                  initialData);

              newInteractionsPromise.then(function(result) {
                if (result.genotype_a_phenotype_annotations.length == 0) {
                  editedAnnotation.interaction_annotations.push(result);
                } else {
                  editedAnnotation.interaction_annotations_with_phenotypes.push(result);
                }

                storeAnnotationToaster(AnnotationProxy, $scope.annotation,
                                       editedAnnotation, toaster)
                  .then(function() {
                    copyObject(editedAnnotation, $scope.annotation);
                  });
              })
              .finally(() => {
                $scope.editInProgress = false;
              });
            } else {
              const editPromise = editGenotypeInteractions($uibModal, $scope.annotation,
                                                           annotationType,
                                                           initialData);

              editPromise.finally(() => {
                $scope.editInProgress = false;
              });
            }
          });
          });
        };

        $scope.genotypeInteractionCount = function() {
          var count = 0;
          var annotation = $scope.annotation;
          if (annotation.interaction_annotations) {
            count += annotation.interaction_annotations.length;
          }
          if (annotation.interaction_annotations_with_phenotypes) {
            count += annotation.interaction_annotations_with_phenotypes.length;
          }

          return count;
        };

        $scope.transferAnnotation = function() {
          startTransfer($uibModal, $scope.annotation, $scope.featureFilterDisplayName);
        };

        $scope.duplicate = function () {
          var newAnnotation = makeNewAnnotation($scope.annotation);
          newAnnotation.interaction_annotations = [];
          newAnnotation.interaction_annotations_with_phenotypes = [];
          startEditing($uibModal, annotation.annotation_type,
            newAnnotation, $scope.featureFilterDisplayName,
            true, true);
        };

        $scope.confirmDelete = function () {
          var modal = openDeleteDialog(
            $uibModal,
            'Delete Annotation',
            'Delete Annotation',
            'Are you sure you want to delete this annotation?'
          );
          modal.result.then(function () {
            $scope.deleteAnnotation();
          });
        };

        $scope.deleteAnnotation = function () {
          loadingStart();
          AnnotationProxy.deleteAnnotation(annotation)
            .then(function () {
              toaster.pop('success', 'Annotation deleted');
            })
            .catch(function (message) {
              toaster.pop('note', "Couldn't delete the annotation: " + message);
            })
            .finally(function () {
              loadingEnd();
            });
        };
      },
    };
  };

canto.directive('annotationTableRow',
   ['$uibModal', '$q', '$http', 'CursGenotypeList',
    'CursSessionDetails', 'CursAnnotationDataService',
    'AnnotationProxy', 'AnnotationTypeConfig',
    'CantoGlobals', 'CantoConfig', 'CantoService', 'toaster',
    annotationTableRow
  ]);


var annotationSingleRowTable =
  function (AnnotationTypeConfig, CantoConfig, CantoService, Curs) {
    return {
      restrict: 'E',
      scope: {
        featureType: '@',
        featureDisplayName: '@',
        annotationTypeName: '@',
        annotationDetails: '=',
      },
      replace: true,
      templateUrl: function () {
        return app_static_path + 'ng_templates/annotation_single_row_table.html';
      },
      controller: function ($scope) {
        $scope.displayFeatureType = capitalizeFirstLetter($scope.featureType);

        $scope.showEvidenceColumn = true;

        AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function (annotationType) {
            $scope.annotationType = annotationType;

            $scope.showEvidenceColumn =
              annotationType.evidence_codes &&
              annotationType.evidence_codes.length > 0;
          });
      },
    };
  };

canto.directive('annotationSingleRowTable',
  ['AnnotationTypeConfig', 'CantoConfig', 'CantoService', 'Curs',
    annotationSingleRowTable
  ]);


var annotationSingleRow =
  function (AnnotationTypeConfig, CantoConfig, CantoService, Curs) {
    return {
      restrict: 'A',
      scope: {
        featureDisplayName: '@',
        annotationType: '=',
        annotationDetails: '=',
      },
      replace: true,
      templateUrl: function () {
        return app_static_path + 'ng_templates/annotation_single_row.html';
      },
      controller: function ($scope) {
        $scope.displayEvidence = '';
        $scope.conditionsString = '';
        $scope.withGeneDisplayName = '';
        $scope.showEvidenceColumn = true;

        $scope.showEvidenceColumn =
          $scope.annotationType.evidence_codes &&
          $scope.annotationType.evidence_codes.length > 0;

        $scope.$watch('annotationDetails.term_ontid',
          function (newId) {
            if (newId) {
              CantoService.lookup('ontology', [newId], {
                  def: 1,
                  children: 1,
                  exact_synonyms: 1,
                  subset_ids: 1,
                })
                .then(function (data) {
                  $scope.termDetails = data;
                });
            } else {
              $scope.termDetails = {};
            }
          });

        $scope.$watch('annotationDetails.conditions',
          function (newConditions) {
            if (newConditions) {
              $scope.conditionsString =
                conditionsToString(newConditions);
            }
          },
          true);

        $scope.$watch('annotationDetails.evidence_code',
          function (newCode) {
            $scope.displayEvidence = newCode;

            if (newCode) {
              CantoConfig.get('evidence_types').then(function (results) {
                $scope.evidenceTypes = results;
                $scope.displayEvidence = results[newCode].name;
              });
            }
          });

        $scope.$watch('annotationDetails.with_gene_id',
          function (newWithId) {
            if (newWithId) {
              Curs.list('gene').then(function (results) {
                $scope.genes = results;

                $.map($scope.genes,
                  function (gene) {
                    if (gene.gene_id == newWithId) {
                      $scope.withGeneDisplayName =
                        gene.primary_name || gene.primary_identifier;
                    }
                  });
              });
            } else {
              $scope.withGeneDisplayName = '';
            }
          });
      },
    };
  };

canto.directive('annotationSingleRow',
  ['AnnotationTypeConfig', 'CantoConfig', 'CantoService', 'Curs',
    annotationSingleRow
  ]);



var interactionAnnotationSingleRow =
  function (AnnotationTypeConfig, CantoConfig, CantoService, Curs) {
    return {
      restrict: 'E',
      scope: {
        annotation: '=',
        annotationTypeName: '@'
      },
      replace: true,
      templateUrl: function () {
        return app_static_path + 'ng_templates/interaction_annotation_single_row.html';
      },
      controller: function ($scope) {
        $scope.annotationType = null;

        $scope.data = {
          hideColumns: {},
        };

        copyObject(initialHideColumns, $scope.data.hideColumns);

        // the curator details aren't helpful here
        $scope.data.hideColumns['curator'] = true;

        AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function(annotationType) {
            $scope.annotationType = annotationType;
            setHideColumns($scope.annotation, $scope.data.hideColumns);
            if ($scope.annotationType.annotation_table_columns_to_hide) {
              // force some columns to be hidden even if they aren't empty
              $.map(annotationType.annotation_table_columns_to_hide,
                    function(columnName) {
                      $scope.data.hideColumns[columnName] = true;
                    });
            }
          });

      }
    };
  };

canto.directive('interactionAnnotationSingleRow',
  ['AnnotationTypeConfig', 'CantoConfig', 'CantoService', 'Curs',
    interactionAnnotationSingleRow
  ]);


var termNameComplete =
  function (CantoGlobals, CantoConfig, AnnotationTypeConfig, CantoService, $q, $timeout) {
    return {
      scope: {
        annotationTypeName: '@',
        currentTermName: '@',
        foundCallback: '&',
        mode: '@',
        size: '@',
      },
      controller: function ($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.termCount = null;
        $scope.allTerms = [];
        $scope.annotationType = null;

        AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function (annotationType) {
            $scope.annotationType = annotationType;
          });

        $scope.extensionLookup = ($scope.mode && $scope.mode == 'extension' ? 1 : 0);

        $scope.maxTermNameSelectCount = CantoGlobals.max_term_name_select_count;

        $scope.isShortList = function() {
          return $scope.termCount && $scope.termCount <= $scope.maxTermNameSelectCount;
        };

        $scope.placeholder = '';

        var re = new RegExp(/\[([^[\]]+)\]/);
        $scope.typeMatch = re.exec($scope.annotationTypeName);

        if ($scope.typeMatch) {
          $scope.placeholder = 'Start typing a term name, e.g. ';
          var split = $scope.typeMatch[1].split(/\s*\|\s*/);
          var promises =
            $.map(split,
              function (termId) {
                return CantoService.lookup('ontology', [termId], {});
              });
          $q.all(promises).then(function (results) {
            $scope.placeholder +=
              $.map(results, function (data) {
                return data.name;
              }).join(" or ") + "...";
          });
        }

        $scope.render_term_item =
          function (ul, item, search_string) {
            var searchAnnotationTypeName = $scope.annotationTypeName;
            var search_bits = search_string.split(/\W+/);
            var match_name = item.matching_synonym;
            var synonym_extra = '';
            if (match_name) {
              synonym_extra = ' (synonym)';
            } else {
              match_name = item.name;
            }
            var warning = '';
            if (searchAnnotationTypeName.indexOf('[') != 0 &&
                // if the namespace isn't set we're searching GO terms so this
                // isn't a problem:
                $scope.annotationType && !$scope.annotationType.namespace &&
                typeof item.annotation_type_name !== 'undefined' &&
                searchAnnotationTypeName !== item.annotation_type_name) {
              warning = '<br/><span class="autocomplete-warning">WARNING: this is the ID of a ' +
                item.annotation_type_name + ' term but<br/>you are browsing ' +
                searchAnnotationTypeName + ' terms</span>';
              var re = new RegExp('_', 'g');
              // unpleasant hack to make the namespaces look nicer
              warning = warning.replace(re, ' ');
            }

            function length_compare(a, b) {
              if (a.length < b.length) {
                return 1;
              }
              if (a.length > b.length) {
                return -1;
              }
              return 0;
            }
            search_bits.sort(length_compare);
            for (var i = 0; i < search_bits.length; i++) {
              var bit = search_bits[i];
              if (bit.length > 1) {
                var boldRE = new RegExp('(\\b' + bit + ')', "gi");
                match_name = match_name.replace(boldRE, '<b>$1</b>');
              }
            }
            return $("<li></li>")
              .data("item.autocomplete", item)
              .append("<a>" + match_name + " <span class='term-id'>(" +
                item.id + ")</span>" + synonym_extra + warning + "</a>")
              .appendTo(ul);
          };
      },
      replace: true,
      restrict: 'E',
      templateUrl: app_static_path + 'ng_templates/term_name_complete.html',
      link: function (scope, elem) {
        if (!scope.size) {
          scope.size = 40;
        }

        var valBeforeComplete = null;
        var input = $(elem).find('input');
        input.autocomplete({
          minLength: 2,
          source: make_ontology_complete_url(scope.annotationTypeName, scope.extensionLookup),
          cacheLength: 100,
          focus: ferret_choose.show_autocomplete_def,
          open: function () {
            valBeforeComplete = input.val();
          },
          close: ferret_choose.hide_autocomplete_def,
          select: function (event, ui) {
            var trimmedValBeforeComplete = null;
            if (valBeforeComplete) {
              trimmedValBeforeComplete = trim(valBeforeComplete);
            }
            $timeout(function () {
              scope.foundCallback({
                termId: ui.item.id,
                termName: ui.item.value,
                searchString: trimmedValBeforeComplete,
                matchingSynonym: ui.item.matching_synonym,
              });
            }, 1);
            valBeforeComplete = null;
            ferret_choose.hide_autocomplete_def();
          },
        }).data("autocomplete")._renderItem = function (ul, item) {
          var search_string = input.val();
          return scope.render_term_item(ul, item, search_string);
        };
        input.attr('disabled', false);

        function do_autocomplete() {
          input.focus();
          scope.$apply(function () {
            input.autocomplete('search');
          });
        }

        function show_all() {
          input.focus();
          scope.$apply(function () {
            input.autocomplete('search', ':ALL:');
          });
        }

        CantoService.lookup('ontology', [scope.annotationTypeName,
                                         ':COUNT:'
                                        ], {
                                          extension_lookup: scope.extensionLookup
                                        })
          .then(function (data) {
            scope.termCount = data.count;
            if (scope.isShortList()) {
              setTimeout(show_all, 100);
              scope.placeholder = 'Choose a term ...  (type to filter)';
           }
          });

        input.bind('paste', function () {
          setTimeout(do_autocomplete, 10);
        });

        input.bind('click', function () {
          if (scope.isShortList()) {
            show_all();
          } else {
            setTimeout(do_autocomplete, 10);
          }
        });

        input.keypress(function (event) {
          if (event.which == 13) {
            // return should autocomplete not submit the form
            event.preventDefault();
            do_autocomplete();
          }
        });

        input.keyup(function (event) {
          var value = input.val();

          if (trim(value).length == 0) {
            $timeout(
              function () {
                scope.foundCallback({
                  termId: null,
                  termName: null,
                  searchString: '',
                  matchingSynonym: null,
                });
              },
              1);
          }
        });

        var select = $(elem).find('select');

        select.change(function () {
          $timeout(function () {
            var termId = null;
            var termName = null;
            if (scope.chosenTerm) {
              termId = scope.chosenTerm.id;
              termName = scope.chosenTerm.name;
            }
            scope.foundCallback({
              termId: termId,
              termName: termName,
              searchString: null,
              matchingSynonym: null,
            });
          }, 1);
        });
      }
    };
  };

canto.directive('termNameComplete',
  ['CantoGlobals', 'CantoConfig', 'AnnotationTypeConfig',
    'CantoService', '$q', '$timeout',
    termNameComplete
  ]);


var termChildrenQuery =
  function ($uibModal, CantoService) {
    return {
      scope: {
        termId: '=',
        termName: '=',
      },
      controller: function ($scope) {
        $scope.data = {
          children: []
        };

        $scope.confirmTerm = function () {
          var termConfirm = openTermConfirmDialog($uibModal, $scope.termId, 'children');

          termConfirm.result.then(function (result) {
            $scope.termId = result.newTermId;
            $scope.termName = result.newTermName;
          });
        };
      },
      replace: true,
      restrict: 'E',
      templateUrl: app_static_path + 'ng_templates/term_children_query.html',
      link: function ($scope) {
        $scope.$watch('termId',
          function (newTermId) {
            if (newTermId) {
              var promise = CantoService.lookup('ontology', [$scope.termId], {
                def: 1,
                children: 1,
                exact_synonyms: 1,
              });

              promise.then(function (data) {
                if (!data.children || data.children.length == 0) {
                  $scope.data.children = [];
                } else {
                  $scope.data.children = data.children;
                }
              });
            } else {
              $scope.data.children = [];
            }
          });
      }
    };
  };

canto.directive('termChildrenQuery', ['$uibModal', 'CantoService', termChildrenQuery]);


var initiallyHiddenText =
  function () {
    return {
      scope: {
        text: '@',
        linkLabel: '@',
        previewCharCount: '@',
        breakOnComma: '@',
      },
      restrict: 'E',
      replace: true,
      link: function ($scope) {
        $scope.previewChars = '';
        $scope.hidden = true;

        $scope.trimmedText = $.trim($scope.text);

        $scope.show = function () {
          $scope.hidden = false;
        };

        $scope.$watch('text',
          function () {
            $scope.trimmedText = $.trim($scope.text);

            if ($scope.breakOnComma) {
              $scope.trimmedText = $scope.trimmedText.replace(/,/g, ', ');
            }

            if ($scope.previewCharCount && $scope.previewCharCount > 0) {
              if ($scope.previewCharCount < $scope.trimmedText.length) {
                $scope.previewChars = $scope.text.substr(0, $scope.previewCharCount);
              } else {
                $scope.hidden = false;
              }
            }
          });
      },
      template: '<span ng-show="trimmedText.length > 0">' +
        '<span ng-hide="hidden" ng-bind-html="trimmedText | toTrusted"></span>' +
        '<span ng-show="hidden" uib-tooltip="{{trimmedText}}">' +
        '  <span ng-click="show()" ng-show="previewChars.length > 0" ng-bind-html="previewChars | toTrusted"></span>' +
        '  <a ng-click="show()">&nbsp;<span style="font-weight: bold">{{linkLabel}}</span></a>' +
        '</span></span>',
    };
  };

canto.directive('initiallyHiddenText', [initiallyHiddenText]);


var userPubsLookupCtrl =
  function (CantoGlobals, CantoService) {
    return {
      scope: {
        initialEmailAddress: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/user_pubs_lookup.html',
      controller: function ($scope) {
        var maxPubs = 10;

        $scope.emailAddress = $scope.initialEmailAddress;

        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.is_admin_user = CantoGlobals.is_admin_user;
        $scope.application_root = CantoGlobals.application_root;

        $scope.searching = false;
        $scope.truncatedList = true;

        $scope.updateLists = function () {
          $scope.activeList = [];
          $scope.completedList = [];

          for (var i = 0; i < $scope.pubResults.length; i++) {
            var pub = $scope.pubResults[i];
            if ($.inArray(pub.status, activeSessionStatuses) >= 0) {
              if (!$scope.truncatedList || $scope.activeList.length < maxPubs) {
                $scope.activeList.push(pub);
              }
            } else {
              if (!$scope.truncatedList || $scope.completedList.length < maxPubs) {
                $scope.completedList.push(pub);
              }
            }

            if ($scope.truncatedList) {
              if ($scope.activeList.length == maxPubs &&
                $scope.completedList.length == maxPubs) {
                break;
              }
            }
          }
        };

        $scope.showAll = function () {
          $scope.truncatedList = false;
          $scope.updateLists();
        };

        $scope.search = function () {
          $scope.pubResults = null;
          if ($scope.emailAddress) {
            $scope.searching = true;
            var pathParts = ['by_curator_email', $scope.emailAddress];
            var promise =
              CantoService.lookup('pubs', pathParts, {});

            promise.then(function (data) {
              if (data.status == 'success') {
                $scope.pubResults = data.pub_results;
                $scope.updateLists();
                $scope.truncatedList =
                  $scope.activeList.length + $scope.completedList.length < $scope.pubResults.length;
              }
            });

            promise.finally(function () {
              $scope.searching = false;
            });
          }
        };

        $scope.reset = function () {
          $scope.pubResults = null;
          $scope.activeList = null;
          $scope.completedList = null;
          $scope.count = -1;
        };

        $scope.reset();
      },
    };
  };

canto.directive('userPubsLookup',
  ['CantoGlobals', 'CantoService', userPubsLookupCtrl]);


var pubsListViewCtrl =
  function (CantoGlobals) {
    return {
      scope: {
        rows: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/pubs_list_view.html',
      controller: function ($scope) {
        $scope.CantoGlobals = CantoGlobals;
        $scope.application_root = CantoGlobals.application_root;
      },
    };
  };

canto.directive('pubsListView', ['CantoGlobals', pubsListViewCtrl]);


var AnnotationStatsCtrl =
  function ($scope, CantoGlobals) {
    $scope.visibleMap = {};
    $scope.curationStatusLabels = CantoGlobals.curationStatusData[0];
    $scope.curationStatusData = CantoGlobals.curationStatusData.slice(1);
    $scope.cumulativeAnnotationTypeCountsLabels = CantoGlobals.cumulativeAnnotationTypeCounts[0];
    $scope.cumulativeAnnotationTypeCountsData = CantoGlobals.cumulativeAnnotationTypeCounts.slice(1);

    $scope.defaultStackedChartColors = defaultStackedChartColors;

    var currentYear = (new Date()).getFullYear();
    $scope.perPub5YearStatsLabels =
      $.map(CantoGlobals.perPub5YearStatsData[0],
        function (year) {
          if (year == currentYear) {
            return year;
          } else {
            var rangeEnd = (year + 4);
            if (rangeEnd > currentYear) {
              rangeEnd = currentYear;
            }
            return year + "-" + rangeEnd;
          }
        });
    $scope.perPub5YearStatsData = CantoGlobals.perPub5YearStatsData.slice(1);

    $scope.htpPerPub5YearStatsLabels =
      $.map(CantoGlobals.htpPerPub5YearStatsData[0],
        function (year) {
          if (year == currentYear) {
            return year;
          } else {
            var rangeEnd = (year + 4);
            if (rangeEnd > currentYear) {
              rangeEnd = currentYear;
            }
            return year + "-" + rangeEnd;
          }
        });
    $scope.htpPerPub5YearStatsData = CantoGlobals.htpPerPub5YearStatsData.slice(1);

    $scope.show = function ($event, key) {
      $scope.visibleMap[key] = true;
      $event.preventDefault();
    };

    $scope.isVisible = function (key) {
      return $scope.visibleMap[key] || false;
    };
  };

canto.controller('AnnotationStatsCtrl',
  ['$scope', 'CantoGlobals', AnnotationStatsCtrl]);


var stackedGraph =
  function () {
    return {
      scope: {
        chartLabels: '=',
        chartData: '=',
        chartSeries: '@',
        chartColors: '=',
      },
      restrict: 'E',
      replace: true,
      template: '<div><canvas class="chart chart-bar" chart-data="chartData" ' +
        'chart-labels="chartLabels" chart-options="options" ' +
        'chart-colors="chartColors" ' +
        'chart-series="series"></canvas></div>',
      controller: function ($scope) {
        $scope.type = 'StackedBar';
        $scope.series = $scope.chartSeries.split('|');


        var afterBodyCallback = function (items) {
          var total = 0;
          $.map(items, function (el) {
            var i = parseInt(el['yLabel']);
            if (!isNaN(i)) {
              total += i;
            }
          });
          return ['', 'Total: ' + total];
        };

        $scope.options = {
          tooltips: {
            callbacks: {
              afterBody: afterBodyCallback
            }
          },
          legend: {
            display: true
          },
          scales: {
            xAxes: [{
              stacked: true,
            }],
            yAxes: [{
              stacked: true,
            }]
          }
        };
      }
    };
  };

canto.directive('stackedGraph', [stackedGraph]);


var barChart =
  function () {
    return {
      scope: {
        chartLabels: '=',
        chartData: '=',
      },
      restrict: 'E',
      replace: true,
      template: '<div><canvas class="chart chart-bar" chart-data="[chartData]" ' +
        'chart-labels="chartLabels" chart-options="options"></canvas></div>',
      controller: function ($scope) {
        $scope.type = 'Bar';
        $scope.options = {
          legend: {
            display: false
          },
        };
      }
    };
  };

canto.directive('barChart', [barChart]);

canto.service('OrganismList', function ($q, $http) {
  this.getOrganismList = function () {
    var defer = $q.defer();
    $http({
        method: 'GET',
        url: '/ws/lookup/organisms/host',
        cache: 'true'
      })
      .then(function (response) {
        if (response.status === 200) {
          defer.resolve(response.data);
        } else {
          defer.reject(response.status);
        }
      });

    return defer.promise;
  };
});

var organismPicker = function ($http, OrganismList) {
  return {
    scope: {
      selectedOrganisms: '=',
      disabled: '=',
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/oganismPicker.html',
    controller: function ($scope) {
      $scope.app_static_path = app_static_path;
      $scope.getOrganismsFromServer = getOrganismsFromServer;
      $scope.organisms = [];
      $scope.organismsCount = null;
      $scope.selected = '';
      $scope.taxon_ids = '';
      $scope.onSelect = onSelect;
      $scope.updateTaxonIds = updateTaxonIds;
      $scope.removeOrganism = removeOrganism;

      getOrganismsFromServer();

      function getOrganismsFromServer() {
        OrganismList.getOrganismList().then(function (data) {
            data.forEach(function (organism) {
              var commonName = (organism.common_name && (organism.common_name.length > 0)) ?
                " (" + organism.common_name + ")" : "";
              organism.display = "[" + organism.taxonid + "] " + organism.full_name + commonName;
              $scope.organisms.push(organism);
            });
            $scope.organismsCount = $scope.organisms.length;
        });
      }

      function onSelect(organism) {
        if ($scope.selectedOrganisms.indexOf(organism) === -1) {
          $scope.selectedOrganisms.push(organism);
        }
        $scope.selected = '';
        $scope.updateTaxonIds();
      }

      function updateTaxonIds() {
        var taxonIds =
            $scope.selectedOrganisms.map(organism => organism.taxonid);
        $scope.taxon_ids = taxonIds.join(" ");
      }

      function removeOrganism(organism) {
        var id;
        if ((id = $scope.selectedOrganisms.indexOf(organism)) > -1) {
          $scope.selectedOrganisms.splice(id, 1);
        }
        $scope.updateTaxonIds();
      }
    },
  };
};

canto.directive('organismPicker', ['$http', 'OrganismList', organismPicker]);

var genotypeOptions = function () {
  return {
    replace: true,
    scope: {
      genotypeSwitchSelect: '@',
    },
    template: '<div>\n' +
      '<div ng-switch on="genotypeSwitchSelect">\n' +
      '<div ng-switch-when="genotype"><genotype-manage genotype-type="normal" /></div>\n' +
      '<div ng-switch-when="host-genotype"><genotype-manage genotype-type="host" /></div>\n' +
      '<div ng-switch-when="pathogen-genotype"><genotype-manage genotype-type="pathogen" /></div>\n' +
      '<div ng-switch-when="metagenotype"><metagenotype-manage /></div>\n' +
      '</div>\n' +
      '</div>',
  };
};

canto.directive('genotypeOptions', [genotypeOptions]);


var genotypeSimpleListRowCtrl =
  function (CantoGlobals) {
    return {
      restrict: 'A',
      scope: {
        genotype: '<',
        isHost: '<',
        showCheckBoxActions: '<',
        showBackground: '<',
        onGenotypeSelect: '&'
      },
      replace: true,
      templateUrl: CantoGlobals.app_static_path + 'ng_templates/genotype_simple_list_row.html',
      controller: function ($scope) {
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.read_only_curs = CantoGlobals.read_only_curs;

        $scope.inputNameValue = ($scope.isHost ? 'host' : 'pathogen') + '_genotype';

        $scope.genotype.alleles = $scope.genotype.alleles || [];
        $scope.firstAllele = $scope.genotype.alleles[0];
        $scope.otherAlleles = $scope.genotype.alleles.slice(1);

        $scope.data = {
          selectedGenotype: null
        };

        $scope.genotypeSelected = function (genotype) {
          $scope.onGenotypeSelect({
            genotype: genotype
          });
        };
      }
    };
  };

canto.directive('genotypeSimpleListRow', ['CantoGlobals', genotypeSimpleListRowCtrl]);


var genotypeSimpleListViewCtrl =
  function () {
    return {
      scope: {
        genotypeList: '=',
        isHost: '<',
        showCheckBoxActions: '=',
        genotypeModel: '=',
        onGenotypeSelect: '&'
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_simple_list_view.html',
      controller: function ($scope) {
        $scope.showBackground = false;

        $scope.$watch('genotypeList', updateShowBackground);

        $scope.onGenotypeChange = function (genotype) {
          $scope.onGenotypeSelect({
            genotype: genotype
          });
        };

        function updateShowBackground() {
          function hasBackground(genotype) {
            return !! genotype.background;
          }
          $scope.showBackground = $scope.genotypeList.some(hasBackground);
        }
      }
    };
  };

canto.directive('genotypeSimpleListView', [genotypeSimpleListViewCtrl]);

var wildTypeGenotypePicker = function () {
    return {
      scope: {
        strains: '<',
        onStrainSelect: '&'
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/wild_type_genotype_picker.html',
    };
  };

canto.directive('wildTypeGenotypePicker', [wildTypeGenotypePicker]);

var metagenotypeGenotypePicker =
  function (CantoGlobals, CursGenotypeList, toaster, Metagenotype, StrainsService) {
    return {
      scope: {
        isHost: '<',
        selectedOrganism: '<',
        genotypes: '<',
        onGenotypeSelect: '&',
        onStrainSelect: '&'
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/metagenotype_genotype_picker.html',
      controller: function ($scope) {

        $scope.organismType = $scope.isHost ? 'host' : 'pathogen';
        $scope.organismLabel = capitalizeFirstLetter($scope.organismType);
        $scope.genotypeShortcutUrl = setGenotypeShortcut($scope.organismType);

        $scope.data = {
          wildTypeStrains: [],
        };

        if ($scope.isHost) {
          $scope.$watch('selectedOrganism', function () {
            if ($scope.selectedOrganism) {
              $scope.loadWildTypeStrains();
            }
          });
        }

        function setGenotypeShortcut(organismType) {
          return CantoGlobals.curs_root_uri + '/' +
            organismType.toLowerCase() +
            '_genotype_manage';
        }

        $scope.loadWildTypeStrains = function () {
          StrainsService.getSessionStrains($scope.selectedOrganism.taxonid)
            .then(function (strains) {
              $scope.data.wildTypeStrains = strains;
            });
        };

        $scope.setDefaultGenotype = function () {
          var defaultGenotype = null;
          if ($scope.data.singleAlleleGenotypes.length > 0) {
            defaultGenotype = $scope.data.singleAlleleGenotypes[0];
          } else if ($scope.data.multiAlleleGenotypes.length > 0) {
            defaultGenotype = $scope.data.multiAlleleGenotypes[0];
          } else {
            defaultGenotype = $scope.data.wildType;
          }
        };

        $scope.setFilters = function () {
          $scope.setDefaultGenotype();
        };

        $scope.onGenotypeChangeSingle = function (genotype) {
          $scope.onGenotypeSelect({
            genotype: genotype
          });
        };

        $scope.onGenotypeChangeMulti = function (genotype) {
          $scope.onGenotypeSelect({
            genotype: genotype
          });
        };

        $scope.onStrainChange = function (strain) {
          $scope.onStrainSelect({
            strain: strain
          });
        };

        if ($scope.isHost) {
          StrainsService.getAllSessionStrains();
        }
      },
    };
  };

canto.directive('metagenotypeGenotypePicker',
  ['CantoGlobals', 'CursGenotypeList', 'toaster', 'Metagenotype', 'StrainsService', metagenotypeGenotypePicker]);


var metagenotypeListRow = function (CantoGlobals, Metagenotype, AnnotationTypeConfig) {
  return {
    scope: {
      metagenotype: '<',
      showBackground: '<'
    },
    restrict: 'A',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/metagenotype_list_row.html',
    controller: function ($scope) {
      $scope.getOrganismName = function (type) {
        var metagenotype = $scope.metagenotype[type + '_genotype'];
        var name = metagenotype.organism.full_name || '';
        return name;
      };
      $scope.getStrainName = function (type) {
        var metagenotype = $scope.metagenotype[type + '_genotype'];
        var strain = metagenotype.strain_name;
        return '(' + strain + ')';
      };

      $scope.getScope = function (type) {
        var name = $scope.metagenotype[type + '_genotype'].organism.full_name || '';
        var pos = name.indexOf('(');
        if (pos !== -1) {
          return name.substring(++pos, (name.length - 1));
        }
        return '-';
      };

      $scope.read_only_curs = CantoGlobals.read_only_curs;
      $scope.curs_root_uri = CantoGlobals.curs_root_uri;

      $scope.matchingAnnotationTypes = [];

      AnnotationTypeConfig.getAll().then(function (data) {
        $scope.matchingAnnotationTypes =
          $.grep(data, function (annotationType) {
            return annotationType.feature_type === 'metagenotype';
          });
      });

      $scope.viewAnnotationUri = CantoGlobals.curs_root_uri + '/feature/metagenotype/view/' + $scope.metagenotype.metagenotype_id;
      if (CantoGlobals.read_only_curs) {
        $scope.viewAnnotationUri += '/ro';
      }

      $scope.delete = function () {
        Metagenotype.delete($scope.metagenotype.metagenotype_id);
      };
    },
  };
};

canto.directive('metagenotypeListRow', ['CantoGlobals', 'Metagenotype', 'AnnotationTypeConfig', metagenotypeListRow]);


var metagenotypeListView = function () {
  return {
    scope: {
      metagenotypes: '<'
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/metagenotype_list_view.html',
    controller: function ($scope) {
      $scope.metagenotypes = null;
      $scope.showBackground = {};

      $scope.$watchCollection('metagenotypes', setBackgroundColumnSettings);

      function setBackgroundColumnSettings(metagenotypes) {
        if (metagenotypes) {
          $scope.showBackground = getBackgroundColumnSettings(metagenotypes);
        }
      }

      function getBackgroundColumnSettings(metagenotypes) {
        var backgroundFinder = function (organismType) {
          return function (metagenotype) {
            var genotype = metagenotype[organismType + '_genotype'];
            return (
              genotype.organism.pathogen_or_host === organismType &&
              !! genotype.background
            );
          };
        };
        return {
          'pathogen': metagenotypes.some(backgroundFinder('pathogen')),
          'host': metagenotypes.some(backgroundFinder('host')),
        };
      }

    }
  };
};

canto.directive('metagenotypeListView', [metagenotypeListView]);


var metagenotypeManage = function ($q, CantoGlobals, Curs, CursGenotypeList, Metagenotype, StrainsService) {
  return {
    scope: {},
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/metagenotype_manage.html',
    controller: function ($scope) {

      $scope.pathogenOrganisms = null;
      $scope.selectedPathogen = null;
      $scope.selectedPathogenGenotypes = null;
      $scope.selectedGenotypePathogen = null;

      $scope.hostOrganisms = null;
      $scope.selectedHost = null;
      $scope.selectedHostGenotypes = null;
      $scope.selectedGenotypeHost = null;
      $scope.selectedHostStrain = null;

      $scope.taxonGenotypeMap = null;

      $scope.metagenotypes = null;
      $scope.filteredMetagenotypes = null;

      $scope.$on('metagenotype:updated', function (event, data) {
        $scope.metagenotypes = data;
        $scope.filteredMetagenotypes = filterMetagenotypesBySelectedOrganisms(
          $scope.selectedPathogen, $scope.selectedHost, $scope.metagenotypes
        );
      });
      $scope.$on('metagenotype list changed', function () {
        Metagenotype.load();
      });

      $scope.genotypeUrl = CantoGlobals.curs_root_uri;
      $scope.makeInvalid = true;
      $scope.display = (!CantoGlobals.read_only_curs);

      $scope.onPathogenSelected = function (organism) {
        $scope.selectedPathogen = organism;
        $scope.selectedGenotypePathogen = null;
        if (organism) {
          var taxonId = organism.taxonid;
          $scope.selectedPathogenGenotypes = $scope.taxonGenotypeMap[taxonId];
        } else {
          $scope.selectedPathogenGenotypes = null;
        }
        $scope.filteredMetagenotypes = filterMetagenotypesBySelectedOrganisms(
          $scope.selectedPathogen, $scope.selectedHost, $scope.metagenotypes
        );
      };

      $scope.onPathogenGenotypeSelect = function (genotype) {
        $scope.selectedGenotypePathogen = genotype;
      };

      $scope.onHostSelected = function (organism) {
        $scope.selectedHost = organism;
        $scope.selectedGenotypeHost = null;
        $scope.selectedHostStrain = null;
        if (organism) {
          var taxonId = organism.taxonid;
          if (taxonId in $scope.taxonGenotypeMap) {
            $scope.selectedHostGenotypes = $scope.taxonGenotypeMap[taxonId];
          } else {
            $scope.selectedHostGenotypes = {
              'single': [],
              'multi': []
            };
          }
        } else {
          $scope.selectedHostGenotypes = null;
        }
        $scope.filteredMetagenotypes = filterMetagenotypesBySelectedOrganisms(
          $scope.selectedPathogen, $scope.selectedHost, $scope.metagenotypes
        );
      };

      $scope.onHostGenotypeSelect = function (genotype) {
        $scope.selectedGenotypeHost = genotype;
        $scope.selectedHostStrain = null;
      };

      $scope.onHostStrainSelect = function (strain) {
        $scope.selectedHostStrain = strain;
        $scope.selectedGenotypeHost = null;
      };

      $scope.toGenotype = function () {
        window.location.href = $scope.genotypeUrl +
          (CantoGlobals.read_only_curs ? '/ro' : '');
      };

      $scope.isMetagenotypeInvalid = function () {
        return ! (
          $scope.selectedGenotypePathogen && (
            $scope.selectedGenotypeHost || $scope.selectedHostStrain
          )
        );
      };

      $scope.createMetagenotype = function () {
        var wildTypeGenotypeExists = !! $scope.selectedHostStrain;

        if (wildTypeGenotypeExists) {
          createWildTypeMetagenotype();
        } else {
          createNormalMetagenotype();
        }
      };

      onInit();

      function onInit() {
        var promises = {
          genotypes: loadGenotypes(),
          organisms: loadOrganisms()
        };
        $q.all(promises).then(function (results) {
          var organisms = results.organisms;
          var genotypes = results.genotypes;

          $scope.pathogenOrganisms = filterOrganisms(organisms, 'pathogen');
          $scope.hostOrganisms = filterOrganisms(organisms, 'host');
          $scope.taxonGenotypeMap = makeTaxonGenotypeMap(genotypes, organisms);
        });
        StrainsService.getAllSessionStrains();
        Metagenotype.load();
      }

      function loadOrganisms() {
        return Curs.list('organism');
      }

      function loadGenotypes() {
        return CursGenotypeList.cursGenotypeList({include_allele: 1});
      }

      function makeTaxonGenotypeMap(genotypes, organisms) {
        var taxonGenotypeMap;
        var getGenotypeTaxonId = function (genotype) {
          return genotype.organism.taxonid;
        };
        taxonGenotypeMap = indexArray(genotypes, getGenotypeTaxonId);
        taxonGenotypeMap = addTaxonsWithNoGenotypes(taxonGenotypeMap, organisms);
        return splitGenotypeMapByAlleleCount(taxonGenotypeMap);
      }

      function addTaxonsWithNoGenotypes(genotypeMap, organisms) {
        var newMap = angular.copy(genotypeMap);
        var i, org, taxonId;
        for (i = 0; i < organisms.length; i += 1) {
          org = organisms[i];
          taxonId = org.taxonid;
          if (! (taxonId in newMap)) {
            newMap[taxonId] = [];
          }
        }
        return newMap;
      }

      function splitGenotypeMapByAlleleCount(genotypeMap) {
        var newMap = {};
        var genotypes, taxonId;
        for (taxonId in genotypeMap) {
          if (genotypeMap.hasOwnProperty(taxonId)) {
            genotypes = genotypeMap[taxonId];
            newMap[taxonId] = splitGenotypesByAlleleCount(genotypes);
          }
        }
        return newMap;
      }

      function splitGenotypesByAlleleCount(genotypes) {
        var splitObject = {
          'single': [],
          'multi': []
        };
        genotypes.forEach(function (g) {
          if (isSingleLocusGenotype(g)) {
            splitObject['single'].push(g);
          } else {
            splitObject['multi'].push(g);
          }
        });
        return splitObject;
      }

      function createNormalMetagenotype() {
        var pathogenGenotypeId = $scope.selectedGenotypePathogen.genotype_id;
        var hostGenotypeId = $scope.selectedGenotypeHost.genotype_id;
        Metagenotype.create({
          pathogen_genotype_id: pathogenGenotypeId,
          host_genotype_id: hostGenotypeId
        });
      }

      function createWildTypeMetagenotype() {
        var pathogenGenotypeId = $scope.selectedGenotypePathogen.genotype_id;
        var hostStrainTaxonId = $scope.selectedHostStrain.taxon_id;
        var hostStrainName = $scope.selectedHostStrain.strain_name;
        Metagenotype.create({
          pathogen_genotype_id: pathogenGenotypeId,
          host_taxon_id: hostStrainTaxonId,
          host_strain_name: hostStrainName
        });
      }

      function filterMetagenotypesBySelectedOrganisms(selectedPathogen, selectedHost, metagenotypes) {
        var selectedPathogenId;
        var selectedHostId;
        function filterByOrganisms(metagenotype) {
          var pathogenId = metagenotype.pathogen_genotype.organism.taxonid;
          var hostId = metagenotype.host_genotype.organism.taxonid;
          if (!selectedHostId) {
            return pathogenId == selectedPathogenId;
          } else if (!selectedPathogenId) {
            return hostId == selectedHostId;
          } else {
            return pathogenId == selectedPathogenId && hostId == selectedHostId;
          }
        }
        if (selectedPathogen) {
          selectedPathogenId = selectedPathogen.taxonid;
        }
        if (selectedHost) {
          selectedHostId = selectedHost.taxonid;
        }
        if (selectedPathogenId || selectedHostId) {
          return metagenotypes.filter(filterByOrganisms);
        }
        return metagenotypes;
      }
    }
  };
};

canto.directive('metagenotypeManage', ['$q', 'CantoGlobals', 'Curs', 'CursGenotypeList', 'Metagenotype', 'StrainsService', metagenotypeManage]);


canto.service('StrainsService', function (CantoService, Curs, $q, toaster) {

  var vm = this;

  vm.strainPromise = null;
  vm.sessionStrains = [];

  vm.getStrainPromise = function () {
    if (!vm.strainPromise) {
      vm.strainPromise = Curs.list('strain').then(function (data) {
        vm.sessionStrains.length = 0;
        vm.sessionStrains.push.apply(vm.sessionStrains, data);
        return vm.sessionStrains;
      });
    }
    return vm.strainPromise;
  };

  vm.getStrainPromise();

  vm.getSessionStrains = function (taxonId) {
    return vm.getStrainPromise()
      .then(function (sessionStrains) {
        return sessionStrains.filter(function (s) {
          return s.taxon_id == taxonId;
        }).sort(function (a, b) {
          return (a.strain_name > b.strain_name) ? 1 : -1;
        });
      });
  };

  vm.getAllSessionStrains = function () {
    return vm.getStrainPromise();
  };

  vm.getStrainById = function (id) {
    return vm.getStrainPromise()
      .then(function (sessionStrains) {
        return sessionStrains.filter(function (strain) {
          return strain.strain_id == id;
        })[0];
      });
  };

  vm.addSessionStrain = function (taxonId, strain) {
    return Curs.add('strain_by_name', [taxonId, strain]).then(function (data) {
      // reset so that strains are re-fetched
      vm.strainPromise = null;
      return data.status;
    });
  };

  vm.removeSessionStrain = function (taxonId, strain) {
    return Curs.delete('strain_by_name', taxonId + '/' + strain).then(function () {
      // reset so that strains are re-fetched
      vm.strainPromise = null;
    }, function (error) {
      toaster.error('Failed to remove strain', error);
    });
  };
});


var strainPicker = function () {
  return {
    scope: {
      taxonId: '@',
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/strain_picker.html',
    controller: 'strainPickerCtrl'
  };
};

canto.directive('strainPicker', strainPicker);

var strainPickerCtrl = function ($scope, StrainsService, CantoService, CantoGlobals) {

  $scope.data = {
    strains: null,
    sessionStrains: null,
    selectedStrain: ''
  };
  $scope.readOnlyMode = CantoGlobals.read_only_curs;

  $scope.unknownStrainAdded = false;

  CantoService.lookup('strains', [$scope.taxonId]).then(function (data) {
    $scope.data.strains = data;
    $scope.getSessionStrains();
  });

  $scope.getSessionStrains = function () {
    StrainsService.getSessionStrains($scope.taxonId)
      .then(function (sessionStrains) {
        $scope.data.sessionStrains = markCustomStrains(sessionStrains);
        $scope.unknownStrainAdded = isUnknownStrainSet();
      });
  };

  $scope.changed = function () {
    if ($scope.data.selectedStrain) {
      var strainName = $scope.data.selectedStrain.strain_name;
      $scope.data.selectedStrain = '';
      StrainsService.addSessionStrain($scope.taxonId, strainName)
        .then($scope.getSessionStrains);
    }
  };

  $scope.remove = function (strain) {
    StrainsService.removeSessionStrain($scope.taxonId, strain)
      .then($scope.getSessionStrains);
  };

  $scope.addStrain = function () {
    if ($scope.data.selectedStrain) {
      var strainName = $scope.data.selectedStrain;
      $scope.data.selectedStrain = '';
      StrainsService.addSessionStrain($scope.taxonId, strainName)
        .then($scope.getSessionStrains);
    }
  };

  $scope.addUnknownStrain = function () {
    if (!$scope.unknownStrainAdded) {
      StrainsService.addSessionStrain($scope.taxonId, 'Unknown strain')
        .then($scope.getSessionStrains);
      $scope.unknownStrainAdded = true;
    }
  };

  $scope.strainFilter = function (value, index, array) {
    function containsSearchText(synonym) {
      return synonym.toUpperCase().indexOf(searchText) !== -1;
    }
    if ($scope.data.selectedStrain) {
      var searchText = $scope.data.selectedStrain.toUpperCase();
      var strainName = value.strain_name.toUpperCase();
      if (strainName.indexOf(searchText) === -1) {
        return value.synonyms.some(containsSearchText);
      }
    }
    return true; // show all results if no text is entered
  };

  function markCustomStrains(sessionStrains) {
    return sessionStrains.map(customStrainMarker);

    function customStrainMarker(strain) {
      var isCustom = true;
      if (strain.strain_name === 'Unknown strain') {
        isCustom = false;
      } else {
        isCustom = ! strainExists(strain, $scope.data.strains);
      }
      strain['is_custom'] = isCustom;
      return strain;
    }

    function strainExists(newStrain, existingStrains) {
      return existingStrains.some(function (existingStrain) {
        return existingStrain.strain_id === newStrain.strain_id;
      });
    }
  }

  function isUnknownStrainSet() {
    return $scope.data.sessionStrains.some(function (strain) {
      return strain.strain_name === 'Unknown strain';
    });
  }

};

canto.controller('strainPickerCtrl', ['$scope', 'StrainsService', 'CantoService', 'CantoGlobals', strainPickerCtrl]);

var strainPickerDialogCtrl =
  function ($scope, $uibModalInstance, args, Curs, toaster) {

    $scope.taxonId = args.taxonId;
    $scope.strainData = {
      strain: null
    };

    getStrainsFromServer($scope.taxonId);

    $scope.strainSelected = function (strain) {
      $scope.strainData.strain = strain;
    };

    $scope.isValid = function () {
      return !!$scope.strainData.strain;
    };

    $scope.ok = function () {
      $uibModalInstance.close($scope.strainData);
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };

    function getStrainsFromServer(taxonId) {
      Curs.list('strain').then(function (strains) {
        $scope.strains = filterStrainsByTaxonId(strains, taxonId);
      }).catch(function () {
        toaster.pop('error', 'failed to get strain list from server');
      });
    }
  };

canto.controller('strainPickerDialogCtrl', ['$scope', '$uibModalInstance', 'args', 'Curs', 'toaster', strainPickerDialogCtrl]);


function selectStrainPicker($uibModal, taxonId) {
  return $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/select_strain_picker.html',
    controller: 'strainPickerDialogCtrl',
    title: 'Select a strain',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function () {
        return {
          taxonId: taxonId,
        };
      }
    },
    backdrop: 'static',
  });
}

var summaryPageGeneList = function (CantoGlobals) {
  return {
    scope: {},
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/summary_page_gene_list.html',
    controller: function ($scope) {
      $scope.readOnlyFragment = getReadOnlyFragment();
      $scope.organismRoles = getOrganismRoles();
      $scope.organisms = getOrganismGroups($scope.organismRoles);
      $scope.organismRoles = removeEmptyRoles(
        $scope.organismRoles,
        $scope.organisms
      );

      $scope.getRoleHeading = function (role) {
        if (role === 'pathogen') {
          return 'Pathogens';
        }
        return 'Hosts';
      };

      $scope.getGeneUrl = function (gene) {
        var root = CantoGlobals.curs_root_uri;
        var readOnly = $scope.readOnlyFragment;
        var url = root + '/feature/gene/view/' + gene.gene_id + readOnly;
        return url;
      };

      function getOrganismRoles() {
        var roles = ['normal'];
        if (CantoGlobals.pathogen_host_mode) {
          roles = ['pathogen', 'host'];
        }
        return roles;
      }

      function removeEmptyRoles(roles, groups) {
        return roles.filter(function(r) {
          return groups[r].length > 0;
        });
      }

      function getOrganismGroups(roles) {
        var allOrganisms = CantoGlobals.organismsAndGenes;
        if (roles.length === 1 && roles[0] === 'normal') {
          return { 'normal': sortGenes(allOrganisms) };
        }
        return groupOrganismsByRole(roles, allOrganisms);
      }

      function sortGenes(organisms) {
        var sortedGenes;
        for (var i = 0; i < organisms.length; i++) {
          sortedGenes = organisms[i].genes.sort(
            sortByProperty('display_name')
          );
          organisms[i].genes = sortedGenes;
        }
        return organisms;
      }

      function groupOrganismsByRole(roles, organisms) {
        var organismGroups = {};
        var filterByRole = function(role) {
          return function (organism) {
            return organism.pathogen_or_host === role;
          };
        };
        var currentOrganisms, role;
        for (var i = 0; i < roles.length; i++) {
          role = roles[i];
          currentOrganisms = organisms
            .filter(filterByRole(role))
            .sort(sortByProperty('full_name'));
          currentOrganisms = sortGenes(currentOrganisms);
          organismGroups[role] = currentOrganisms;
        }
        return organismGroups;
      }

      function getReadOnlyFragment() {
        var isReadOnly = CantoGlobals.read_only_curs;
        var readOnlyFragment = '';
        if (isReadOnly) {
          readOnlyFragment = '/ro';
        }
        return readOnlyFragment;
      }

    }
  };
};

canto.directive('summaryPageGeneList', ['CantoGlobals', summaryPageGeneList]);

canto.service('EditOrganismsSvc', function (toaster, $http, CantoGlobals) {

  var vm = this;

  vm.pathogenOrganisms = null;
  vm.hostOrganisms = null;

  vm.getPathogenOrganisms = function () {
    if (!vm.pathogenOrganisms) {
      var organisms = CantoGlobals.geneListData.pathogen.sort(function (a, b) {
        return (a.scientific_name > b.scientific_name) ? 1 : -1;
      });
      vm.setPathogenOrganisms(organisms);
    }

    return vm.pathogenOrganisms;
  };

  vm.getHostOrganisms = function () {
    if (!vm.hostOrganisms) {
      var allHosts = CantoGlobals.geneListData.host.slice()
        .concat(CantoGlobals.hostsWithNoGenes.map(function (o) {
          o.genes = [];
          return o;
        }))
        .sort(function (a, b) {
          return (a.scientific_name > b.scientific_name) ? 1 : -1;
        });
      vm.setHostOrganisms(allHosts);
    }

    return vm.hostOrganisms;
  };

  vm.setPathogenOrganisms = function (organisms) {
    vm.pathogenOrganisms = organisms;
  };

  vm.setHostOrganisms = function (organisms) {
    vm.hostOrganisms = organisms;
  };

  vm.removeGene = function (gene_id) {
    var url = curs_root_uri + '/edit_genes?gene-select=' + gene_id + '&submit=Remove selected';

    $http.get(url).then(function () {

      toaster.pop('success', 'The gene was deleted');

      var organisms;
      organisms = vm.unsetOrganismGene(vm.pathogenOrganisms, gene_id);
      vm.setPathogenOrganisms(organisms);

      organisms = vm.unsetOrganismGene(vm.hostOrganisms, gene_id);
      vm.setHostOrganisms(organisms);

    }, function () {
      toaster.pop('error', 'There was a problem deleting the gene');
    });
  };

  vm.removeHost = function (taxon_id) {
    var url = curs_root_uri + '/edit_genes?host-org-select=' + taxon_id + '&submit=Remove selected';

    $http.get(url).then(function () {

      toaster.pop('success', 'The host was deleted');

      var organisms;
      organisms = vm.unsetHostOrganism(vm.hostOrganisms, taxon_id);

      vm.setHostOrganisms(organisms);

    }, function () {
      toaster.pop('error', 'There was a problem deleting the host');
    });
  };

  vm.unsetOrganismGene = function (organisms, gene_id) {
    return organisms.map(function (o) {
      o.genes = o.genes.filter(function (g) {
        return g.gene_id !== gene_id;
      });
      return o;
    }).filter(function (o) {
      return o.pathogen_or_host === 'host' || o.genes.length > 0;
    });
  };

  vm.unsetHostOrganism = function (organisms, taxon_id) {
    return organisms.filter(function (o) {
      return o.taxonid !== taxon_id;
    });
  };
});


var editOrganismsGenesTable = function () {
  return {
    scope: {
      genes: '=',
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/edit_organisms_genes_table.html',
    controller: function () {}
  };
};

canto.directive('editOrganismsGenesTable', [editOrganismsGenesTable]);


var editOrganismsTable = function (EditOrganismsSvc, CantoGlobals) {
  return {
    scope: {
      tableTitle: '@',
      organisms: '=',
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/edit_organisms_table.html',
    controller: function ($scope, EditOrganismsSvc) {
      $scope.data = {
        strainsMode: CantoGlobals.strains_mode,
      };
      $scope.readOnlyMode = CantoGlobals.read_only_curs;

      $scope.firstGene = function (genes) {
        if (genes.length > 0) {
          return $scope.geneAttributes(genes[0]);
        }

        return {
          taxonid: "",
          name: "",
          synonyms: "",
          product: "",
        };
      };

      $scope.otherGenes = function (genes) {
        return genes.filter(function (_, index) {
          return index > 0;
        }).map(function (gene) {
          return $scope.geneAttributes(gene);
        });
      };

      $scope.removeGene = function (gene_id) {
        EditOrganismsSvc.removeGene(gene_id);
      };

      $scope.canRemoveHost = function(org) {
        return org.genes.length == 0 && org.genotype_count == 0;
      };

      $scope.removeHost = function (taxon_id) {
        EditOrganismsSvc.removeHost(taxon_id);
      };

      $scope.geneAttributes = function (gene) {
        gene.disabled = false;
        gene.title = "Delete this gene";

        if (gene.annotation_count > 0) {
          gene.disabled = true;
          gene.title = "This gene can't be deleted because it has annotations";
        } else if (gene.genotype_count > 0) {
          gene.disabled = true;
          gene.title = "This gene can't be deleted because there are genotypes involving this gene";
        }

        return gene;
      };
    }
  };
};

canto.directive('editOrganismsTable',
                ['EditOrganismsSvc', 'CantoGlobals', editOrganismsTable]);


var editOrganisms = function ($window, EditOrganismsSvc, StrainsService, CantoGlobals) {
  return {
    scope: {},
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/edit_organisms.html',
    controller: function ($scope) {
      $scope.getPathogens = EditOrganismsSvc.getPathogenOrganisms;
      $scope.getHosts = EditOrganismsSvc.getHostOrganisms;
      $scope.readOnlyMode = CantoGlobals.read_only_curs;
      $scope.continueUrl = curs_root_uri + ($scope.readOnlyMode ? '/ro' : '');
      $scope.addGenesUrl = curs_root_uri + '/gene_upload/';

      $scope.pathogenGeneExists = function () {
        return $scope.getPathogens().length > 0;
      };

      $scope.getWarningType = function () {
        if (!$scope.pathogenGeneExists()) {
          return 'gene';
        }
        if ($scope.hasMissingStrains()) {
          return 'strain';
        }
      };

      $scope.hasMissingStrains = function() {
        if ($scope.getPathogens().length == 0 &&
          $scope.getHosts().length == 0) {
          return true;
        }

        if (!CantoGlobals.strains_mode) {
          return false;
        }

        if (StrainsService.sessionStrains.length == 0) {
          return true;
        }

        var i;

        for (i = 0; i < $scope.getPathogens().length; i++) {
          var pathogen = $scope.getPathogens()[i];
          var pathogenSessStrains = StrainsService.sessionStrains
            .filter(function (strain) {
              return strain.taxon_id == pathogen.taxonid;
            });
          if (pathogenSessStrains.length == 0) {
            return true;
          }
        }

        for (i = 0; i < $scope.getHosts().length; i++) {
          var host = $scope.getHosts()[i];
          var hostSessStrains = StrainsService.sessionStrains
            .filter(function (strain) {
              return strain.taxon_id == host.taxonid;
            });
          if (hostSessStrains.length == 0) {
            return true;
          }
        }

        return false;
      };

      $scope.noPathogenGenes = function() {
        return $scope.getPathogens().length == 0;
      };

      $scope.isContinueUrlDisabled = function () {
        if ($scope.hasMissingStrains()) {
          return true;
        }

        if ($scope.noPathogenGenes()) {
          // if there are no pathogen organism in the session, then there are
          // no genes so we can't continue
          return true;
        }

        return false;
      };

      $scope.getContinueButtonTitle = function () {
        if ($scope.noPathogenGenes()) {
          return 'Please add at least one pathogen gene';
        }

        if ($scope.isContinueUrlDisabled()) {
          return 'Please specify which strains were used for all organisms.';
        } else {
          return 'Continue';
        }
      };

      $scope.goToSummaryPage = function () {
        $window.location.href = $scope.continueUrl;
      };
    }
  };
};

canto.directive('editOrganisms', ['$window', 'EditOrganismsSvc', 'StrainsService', 'CantoGlobals', editOrganisms]);


var genotypeAndSummaryNav = function () {
  return {
    scope: {
      role: '@'
    },
    restrict: 'E',
    templateUrl: app_static_path + 'ng_templates/genotype_and_summary_nav.html',
    controller: 'genotypeAndSummaryNavCtrl',
  };
};

var genotypeAndSummaryNavCtrl = function ($scope, CantoGlobals) {
  var readOnly = CantoGlobals.read_only_curs;
  var readOnlyFragment = readOnly ? '/ro' : '';
  $scope.summaryUrl = CantoGlobals.curs_root_uri + readOnlyFragment;
  $scope.genotypeManageUrl = CantoGlobals.curs_root_uri + '/' + getGenotypeManagePath($scope.role) + readOnlyFragment;
};

canto.controller('genotypeAndSummaryNavCtrl', ['$scope', 'CantoGlobals', genotypeAndSummaryNavCtrl]);

canto.directive('genotypeAndSummaryNav', [genotypeAndSummaryNav]);


var storedMessageEditDialogCtrl =
  function ($scope, $uibModalInstance, toaster, CursSettings, args) {
    $scope.data = {
      dialogTitle: args.dialogTitle,
      message: args.message,
      messageName: args.messageName,
    };

    $scope.finish = function () {
      if ($scope.data.message === args.message) {
        $uibModalInstance.close();
      } else {
        CursSettings.set(args.messageName, $scope.data.message)
        .then(function () {
          $uibModalInstance.close($scope.data.message);
        })
        .catch(function(error) {
          toaster.pop('error', 'Failed to save message: ' + error);
        });
      }
    };

    $scope.cancel = function () {
      $uibModalInstance.dismiss('cancel');
    };
  };

canto.controller('StoredMessageEditDialogCtrl',
  ['$scope', '$uibModalInstance', 'toaster', 'CursSettings',
    'args',
   storedMessageEditDialogCtrl
  ]);


function editStoredMessage($uibModal, dialogTitle, message, messageName) {
  var editInstance = $uibModal.open({
    templateUrl: app_static_path + 'ng_templates/store_message_edit_dialog.html',
    controller: 'StoredMessageEditDialogCtrl',
    title: 'Edit message',
    animate: false,
    size: 'lg',
    resolve: {
      args: function () {
        return {
          dialogTitle: dialogTitle,
          message: message,
          messageName: messageName,
        };
      }
    },
    backdrop: 'static',
  });

  return editInstance.result;
}


var finishedPublicationPageCtrl =
    function ($scope, $uibModal, CursSettings) {
    $scope.messageForCurators = null;

    CursSettings.getAll().then(function (response) {
      $scope.messageForCurators = response.data.message_for_curators;
    });

    $scope.editMessageForCurators = function () {
      if ($scope.messageForCurators) {
        editStoredMessage($uibModal, 'Edit message for curators',
                          $scope.messageForCurators,
                          'message_for_curators')
          .then(function(result) {
            $scope.messageForCurators = result;
          });
      }
    };
  };

canto.controller('FinishedPublicationPageCtrl',
                 ['$scope', '$uibModal', 'CursSettings', finishedPublicationPageCtrl]);
