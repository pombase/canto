"use strict";

/*global history,curs_root_uri,angular,$,make_ontology_complete_url,
  ferret_choose,application_root,window,canto_root_uri,curs_key,
  app_static_path,ontology_external_links,loadingStart,loadingEnd,alert */

var canto = angular.module('cantoApp', ['ui.bootstrap', 'angular-confirm', 'toaster']);

function capitalizeFirstLetter(text) {
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
}

function countKeys(o) {
  var size = 0, key;
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

function copyObject(src, dest, keysFilter) {
  Object.getOwnPropertyNames(src).forEach(function(key) {
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
  Object.getOwnPropertyNames(changedObj).forEach(function(key) {
    if (changedObj[key] !== origObj[key]) {
      dest[key] = changedObj[key];
    }
  });
}

function simpleHttpPost(toaster, $http, url, data) {
  loadingStart();
  $http.post(url, data).
    success(function(data) {
      if (data.status === "success") {
        window.location.href = data.location;
      } else {
        toaster.pop('error', data.message);
      }
    }).
    error(function(data, status){
      loadingEnd();
      toaster.pop('error', "Accessing server failed: " + (data || status) );
    });
}

function conditionsToString(conditions) {
  return $.map(conditions, function(el) { return el.name; }).join (", ");
}

canto.filter('breakExtensions', function() {
  return function(text) {
    if (text) {
      return text.replace(/,/g, ', ').replace(/\|/, " | ");
    }
    return '';
  };
});

canto.filter('toTrusted', ['$sce', function($sce){
  return function(text) {
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

canto.filter('encodeAlleleSymbols', function () {
  return function (item) {
    if (item == null) {
      return null;
    }
    return item.replace(/(delta)\b/g, '&Delta;');
  };
});

canto.config(function($logProvider){
    $logProvider.debugEnabled(true);
});

canto.service('Curs', function($http, $q) {
  this.list = function(key, args) {
    var data = null;

    if (!args) {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/list/';

    if (args.length > 0 && typeof(args[args.length - 1]) === 'object') {
      data = args.pop();
      return $http.post(url + args.join('/'), data);
    }
    // force IE not to cache
    var unique = '?u=' + (new Date()).getTime();
    return $http.get(url + args.join('/') + unique);
  };

  this.details = function(key, args) {
    var data = null;

    if (!args) {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/details/';

    if (args.length > 0 && typeof(args[args.length - 1]) === 'object') {
      data = args.pop();
      return $http.post(url + args.join('/'), data);
    }
    var unique = '?u=' + (new Date()).getTime();
    return $http.get(url + args.join('/') + unique);
  };

  this.add = function(key, args) {
    if (!args) {
      args = [];
    }

    var url = curs_root_uri + '/ws/' + key + '/add/' + args.join('/');
    return $http.get(url);
  };

  this.delete = function(objectType, objectId) {
    var q = $q.defer();

    // POST the curs_key so that a crawled GET can't delete a feature
    // the key is checked on the server
    var details = { key: curs_key };

    var putQ = $http.put(curs_root_uri + '/ws/' + objectType + '/delete/' + objectId,
                        details);

    putQ.success(function(response) {
      if (response.status === 'success') {
        q.resolve();
      } else {
        q.reject(response.message);
      }
    }).error(function(data, status) {
      q.reject('Deletion request failed: ' + status);
    });

    return q.promise;
  };
});

canto.service('CursGeneList', function($q, Curs) {
  this.geneList = function() {
    var q = $q.defer();

    Curs.list('gene').success(function(genes) {
      $.map(genes,
            function(gene) {
              gene.feature_id = gene.gene_id;
            });
      q.resolve(genes);
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };
});

canto.service('CursGenotypeList', function($q, Curs) {
  this.cursGenotypesPromise = null;

  function add_id_or_identifier(genotypes) {
    $.map(genotypes, function(genotype) {
      genotype.id_or_identifier = genotype.genotype_id || genotype.identifier;
      genotype.feature_id = genotype.genotype_id;
    });
  }

  this.cursGenotypeList = function() {
    var q = $q.defer();

    if (this.cursGenotypesPromise == null) {
      this.cursGenotypesPromise = Curs.list('genotype', ['curs_only']);
    }
    this.cursGenotypesPromise.success(function(genotypes) {
      add_id_or_identifier(genotypes);
      q.resolve(genotypes);
    }).error(function(data, status) {
      if (status) {
        q.reject();
      } // otherwise the request was cancelled
    });

    return q.promise;
  };

  this.filteredGenotypeList = function(cursOrAll, filter) {
    var options = {
      filter: filter,
    };
    var filteredCursPromise =
      Curs.list('genotype', [cursOrAll, options]);

    var q = $q.defer();

    filteredCursPromise.success(function(genotypes) {
      add_id_or_identifier(genotypes);
      q.resolve(genotypes);
    }).error(function(data, status) {
      if (status) {
        q.reject();
      } // otherwise the request was cancelled
    });

    return q.promise;
  };

  this.deleteGenotype = function(genotypeList, genotype) {
    var q = $q.defer();

    Curs.delete('genotype', genotype.genotype_id)
    .then(function() {
      arrayRemoveOne(genotypeList, genotype);
      q.resolve();
    })
    .catch(function(message) {
      q.reject(message);
    });

    return q.promise;
  };
});

canto.service('CursAlleleList', function($q, Curs) {
  this.alleleList = function(genePrimaryIdentifier, searchTerm) {
    var q = $q.defer();

    Curs.list('allele', [genePrimaryIdentifier, searchTerm])
      .success(function(alleles) {
        q.resolve(alleles);
      })
      .error(function() {
        q.reject();
      });

    return q.promise;
  };
});

canto.service('CursConditionList', function($q, Curs) {
  this.conditionList = function() {
    var q = $q.defer();

    Curs.list('condition').success(function(conditions) {
      q.resolve(conditions);
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };
});

canto.service('CursSessionDetails', function(Curs) {
  this.promise = Curs.details('session');

  this.get = function() {
    return this.promise;
  };
});

canto.service('CantoGlobals', function($window) {
  this.app_static_path = $window.app_static_path;
  this.application_root = $window.application_root;
  this.curs_root_uri = $window.curs_root_uri;
  this.ferret_choose = $window.ferret_choose;
  this.read_only_curs = $window.read_only_curs;
});

canto.service('CantoService', function($http) {
  this.lookup = function(key, path_parts, params, timeout) {
    return $http.get(application_root + '/ws/lookup/' + key + '/' +
                     path_parts.join('/'),
                     {
                       params: params,
                       timeout: timeout
                     });
  };

  this.details = function(key, params, timeout) {
    return $http.get(application_root + '/ws/details/' + key,
                     {
                       params: params,
                       timeout: timeout
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
//  is_not: true,
  qualifiers: true,
  submitter_comment: true,
  term_ontid: true,
  term_suggestion_name: true,
  term_suggestion_definition: true,
  with_gene_id: true,
  interacting_gene_id: true,
};

var annotationProxy =
  function(Curs, $q, $http) {
    var proxy = this;
    this.allQs = {};
    this.annotationsByType = {};

    this.getAnnotation = function(annotationTypeName) {
      if (!proxy.allQs[annotationTypeName]) {
        var q = $q.defer();
        proxy.allQs[annotationTypeName] = q.promise;

        var cursQ = Curs.list('annotation', [annotationTypeName]);

        cursQ.success(function(annotations) {
          proxy.annotationsByType[annotationTypeName] = annotations;
          q.resolve(annotations);
        });

        cursQ.error(function(data, status) {
          if (status) {
            q.reject();
          } // otherwise the request was cancelled
        });
      }

      return proxy.allQs[annotationTypeName];
    };

    this.deleteAnnotation = function(annotation) {
      var q = $q.defer();

      var details = { key: curs_key,
                      annotation_id: annotation.annotation_id };

      var putQ = $http.put(curs_root_uri + '/ws/annotation/delete', details);

      putQ.success(function(response) {
        if (response.status === 'success') {
          var annotations = proxy.annotationsByType[annotation.annotation_type];
          if (annotations) {
            var index = annotations.indexOf(annotation);
            if (index >= 0) {
              annotations.splice(index, 1);
            }
          }
          q.resolve();
        } else {
          q.reject(response.message);
        }
      }).error(function(data, status) {
        q.reject('Deletion request failed: ' + status);
      });

      return q.promise;
    };

  this.storeChanges = function(annotation, changes, newly_added) {
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
    putQ.success(function(response) {
      if (response.status === 'success') {
        // update local copy
        copyObject(response.annotation, annotation);
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
        q.reject(response.message);
      }
    }).error(function() {
      q.reject();
    });

    return q.promise;
  };
};

canto.service('AnnotationProxy', ['Curs', '$q', '$http', annotationProxy]);

function fetch_conditions(search, showChoices) {
  $.ajax({
    url: make_ontology_complete_url('phenotype_condition'),
    data: { term: search.term, def: 1, },
    dataType: "json",
    success: function(data) {
      var choices = $.map( data, function( item ) {
        var label;
        if (typeof(item.matching_synonym) === 'undefined') {
          label = item.name;
        } else {
          label = item.matching_synonym + ' (synonym)';
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
}

var cursStateService =
  function() {
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
    this.comment = null;

    // return the data in a obj with keys keys suitable for sending to the
    // server
    this.asAnnotationDetails = function() {
      var retVal = {
        term_ontid: this.currentTerm(),
        evidence_code: this.evidence_code,
        with_gene_id: this.with_gene_id,
        conditions: this.conditions,
        term_suggestion_name: null,
        term_suggestion_definition: null,
        extension: this.extension,
        submitter_comment: this.comment,
      };

      if (this.termSuggestion) {
        retVal.term_suggestion_name = this.termSuggestion.name;
        retVal.term_suggestion_definition = this.termSuggestion.definition;
      }

      return retVal;
    };

    // clear the term picked by the term-name-complete and clear the history
    // of child terms we've navigated to
    this.clearTerm = function() {
      this.matchingSynonym = null;
      this.termHistory = [];
    };

    this.addTerm = function(termId) {
      this.termHistory.push(termId);
    };

    this.currentTerm = function() {
      if (this.termHistory.length > 0) {
        return this.termHistory[this.termHistory.length - 1];
      }
      return null;
    };

    this.gotoTerm = function(termId) {
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

    this.setState = function(state) {
      this.state = state;
    };

    this.getState = function() {
      return this.state;
    };
  };

canto.service('CursStateService', ['$q', 'CantoService', cursStateService]);


var cursSettingsService =
  function($http, $timeout, $q) {
    var service = this;

    this.data = {
    };

    this.getAll = function() {
      if (typeof(curs_root_uri) == 'undefined') {
        return {
          then: function (successCallback, errorCallback) {
            errorCallback();
          },
        };
      }
      var unique = '?u=' + (new Date()).getTime();
      return $http.get(curs_root_uri + '/ws/settings/get_all' + unique);
    };

    this.set = function(key, value) {
      var q = $q.defer();

      var unique = '?u=' + (new Date()).getTime();
      var getRes = $http.get(curs_root_uri + '/ws/settings/set/' + key + '/' + value + unique);

      getRes.success(function(result) {
        if (result.status == 'success') {
          service.data[key] = value;
          q.resolve();
        } else {
          q.reject(result.message);
        }
      }).error(function(data, status) {
        q.reject('request failed: ' + status);
      });

      return q.promise;
    };

    service.getAll().success(function(data) {
      $timeout(function() {
              service.data.annotation_mode = data.annotation_mode;
      });
    });

    this.getAnnotationMode = function() {
      return this.annotation_mode;
    };

    this.setAnnotationMode = function(mode) {
      service.set('annotation_mode', mode);
    };

    this.setAdvancedMode = function() {
      return service.setAnnotationMode('advanced');
    };

    this.setStandardMode = function() {
      return service.setAnnotationMode('standard');
    };
  };

canto.service('CursSettings', ['$http', '$timeout', '$q', cursSettingsService]);


var helpIcon = function(CantoGlobals, CantoConfig) {
  return {
    scope: {
      key: '@',
    },
    restrict: 'E',
    replace: true,
    templateUrl: app_static_path + 'ng_templates/help_icon.html',
    controller: function($scope) {
      $scope.helpText = null;

      $scope.app_static_path = CantoGlobals.app_static_path;

      CantoConfig.get('help_text').success(function(results) {
        if (results[$scope.key] && results[$scope.key].inline) {
          $scope.helpText = results[$scope.key].inline;
        }
      });
    },
  };
};

canto.directive('helpIcon', ['CantoGlobals', 'CantoConfig', helpIcon]);


var advancedModeToggle =
  function(CursSettings) {
    return {
      scope: {
      },
      restrict: 'E',
      replace: true,
      template: '<label ng-click="$event.stopPropagation()"><input ng-change="change()" ng-model="advanced" type="checkbox"/>Advanced mode</label>',
      controller: function($scope) {
        $scope.CursSettings = CursSettings;

        $scope.advanced = CursSettings.getAnnotationMode() == 'advanced';

        $scope.$watch('CursSettings.getAnnotationMode()',
                      function(newValue) {
                        $scope.advanced = newValue == 'advanced';
                      });

        $scope.change = function() {
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
  function($compile, CursStateService, CantoService) {
    return {
      scope: {
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        $scope.CursStateService = CursStateService;

        $scope.termDetails = {};

        $scope.clearTerms = function() {
          CursStateService.clearTerm();
        };

        $scope.gotoTerm = function(termId) {
          CursStateService.gotoTerm(termId);
        };

        $scope.currentTerm = function() {
          return CursStateService.currentTerm();
        };

        $scope.lookupPromise = function(termId) {
          return CantoService.lookup('ontology', [termId],
                                     {
                                       def: 1,
                                     });
        };

        $scope.lookupProcess = function(data) {
          if (!data.children || data.children.length == 0) {
            data.children = null;
          }
          if (!data.synonyms || data.synonyms.length == 0) {
            data.synonyms = null;
          } else {
            data.synonyms = $.map(data.synonyms,
                                  function(synonym) {
                                    return synonym.name;
                                  });
          }

          $scope.termDetails[data.term_ontid] = data;

          $scope.render();
        };

        $scope.render = function() {
          var html = '';

          var i, termId, termDetails, makeLink;
          var termHistory = CursStateService.termHistory;
          for (i = 0; i < termHistory.length; i++) {
            termId = termHistory[i];
            makeLink = (i != termHistory.length - 1);

            html += '<div class="breadcrumbs-link">';

            if (makeLink) {
              html += '<a href="#" ng-click="' +
                "gotoTerm('" + termId + "'" + ')">';
            }

            termDetails = $scope.termDetails[termId];
            if (termDetails) {
              html += termDetails.name;
            } else {
              html += termId;
            }

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
      link: function($scope) {
        $scope.$watch('currentTerm()',
                      function(newTermId) {
                        if (newTermId) {
                          if (!$scope.termDetails[newTermId]) {
                            $scope.lookupPromise(newTermId).then($scope.lookupProcess);
                          }
                        }
                      });

      },
      templateUrl: app_static_path + 'ng_templates/breadcrumbs.html',
    };
  };

canto.directive('breadcrumbs', ['$compile', 'CursStateService', 'CantoService',
                                breadcrumbsDirective]);


function openSingleGeneAddDialog($modal)
{
  return $modal.open({
    templateUrl: app_static_path + 'ng_templates/single_gene_add.html',
    controller: 'SingleGeneAddDialogCtrl',
    title: 'Add a new gene by name or identifier',
    animate: false,
    windowClass: "modal",
  });
}


function featureChooserControlHelper($scope, $modal, CursGeneList,
                                     CursGenotypeList, toaster) {
  function getGenesFromServer() {
    CursGeneList.geneList().then(function(results) {
      $scope.features = results;
    }).catch(function() {
      toaster.pop('note', "couldn't read the gene list from the server");
    });
  }

  if ($scope.featureType === 'gene') {
    getGenesFromServer();
  } else {
    CursGenotypeList.cursGenotypeList().then(function(results) {
      $scope.features = results;
    }).catch(function() {
      toaster.pop('note', "couldn't read the genotype list from the server");
    });
  }

  $scope.openSingleGeneAddDialog = function() {
    var modal = openSingleGeneAddDialog($modal);
    modal.result.then(function () {
      getGenesFromServer();
    });
  };

  if ($scope.chosenFeatureUniquename !== undefined ||
      $scope.chosenFeatureDisplayName !== undefined) {
    $scope.$watch('chosenFeatureId',
                  function(newFeatureId) {
                    if (newFeatureId && $scope.features) {
                      $.map($scope.features,
                            function(feature) {
                              if (feature.feature_id === newFeatureId) {
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
}


var multiFeatureChooser =
  function($modal, CursGeneList, CursGenotypeList, toaster) {
    return {
      scope: {
        featureType: '@',
        selectedFeatureIds: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        featureChooserControlHelper($scope, $modal, CursGeneList,
                                    CursGenotypeList, toaster);

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
      },
      templateUrl: app_static_path + 'ng_templates/multi_feature_chooser.html',
    };
  };

canto.directive('multiFeatureChooser',
                ['$modal', 'CursGeneList', 'CursGenotypeList', 'toaster',
                 multiFeatureChooser]);


var featureChooser =
  function($modal, CursGeneList, CursGenotypeList, toaster) {
    return {
      scope: {
        featureType: '@',
        chosenFeatureId: '=',
        chosenFeatureUniquename: '=',
        chosenFeatureDisplayName: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        featureChooserControlHelper($scope, $modal, CursGeneList, CursGenotypeList,
                                    toaster);
      },
      templateUrl: app_static_path + 'ng_templates/feature_chooser.html',
    };
  };

canto.directive('featureChooser',
                ['$modal', 'CursGeneList', 'CursGenotypeList', 'toaster',
                 featureChooser]);


var ontologyTermSelect =
  function() {
    return {
      scope: {
        annotationType: '=',
        termFoundCallback: '&',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/ontology_term_select.html',
      controller: function($scope) {
        $scope.foundCallback = function(termId, termName, searchString, matchingSynonym) {
          $scope.termFoundCallback({ termId: termId,
                                     termName: termName,
                                     searchString: searchString,
                                     matchingSynonym: matchingSynonym,
                                   });
        };
      },
      link: function() {
        $('#loading').unbind('.canto');
        $('#ferret-term-input').attr('disabled', false);
      },
    };
  };

canto.directive('ontologyTermSelect', [ontologyTermSelect]);


var externalTermLinks =
  function(CantoService, CantoConfig) {
    return {
      scope: {
        termId: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/external_term_links.html',
      controller: function($scope) {
        $scope.processExternalLinks = function(linkConfig, newTermId) {
          var link_confs = linkConfig[$scope.termDetails.annotation_namespace];
          if (link_confs) {
            var html = '';
            $.each(link_confs, function(idx, link_conf) {
              var url = link_conf.url;
              // hacky: allow a substitution like WebUtil::substitute_paths()
              var re = new RegExp("@@term_ont_id(?::s/(.+)/(.*)/r)?@@");
              url = url.replace(re,
                                function(match_str, p1, p2) {
                                  if (!p1 || p1.length == 0) {
                                    return newTermId;
                                  }
                                  return newTermId.replace(new RegExp(p1), p2);
                                });
              var img_src =
                  application_root + 'static/images/logos/' +
                  link_conf.icon;
              var title = 'View in: ' + link_conf.name;
              html += '<div class="curs-external-link"><a target="_blank" href="' +
                url + '" title="' + title + '">';
              if (img_src) {
                html += '<img alt="' + title + '" src="' + img_src + '"/></a>';
              } else {
                html += title;
              }
              var link_img_src = application_root + 'static/images/ext_link.png';
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
                      function(newTermId) {
                        if (!newTermId) {
                          return;
                        }

                        CantoService.lookup('ontology', [newTermId],
                                            {
                                              def: 1,
                                            })
                          .then(function(details) {
                            $scope.termDetails = details.data;

                            return CantoConfig.get('ontology_external_links');
                          })
                          .then(function(results) {
                            $scope.processExternalLinks(results.data, newTermId);
                          });
                    });

      },
    };
  };

canto.directive('externalTermLinks',
                ['CantoService', 'CantoConfig', externalTermLinks]);


var ontologyTermConfirm =
  function($modal, toaster, CantoService, CantoConfig, CantoGlobals) {
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
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/ontology_term_confirm.html',
      controller: function($scope) {
        $scope.synonymTypes = [];

        $scope.$watch('annotationType.name',
                      function(typeName) {
                        if (typeName) {
                          $scope.synonymTypes = $scope.annotationType.synonyms_to_display;
                        }
                      });

        $scope.app_static_path = CantoGlobals.app_static_path;

        $scope.$watch('termId',
                      function(newTermId) {
                        if (newTermId) {
                          CantoService.lookup('ontology', [newTermId],
                                              {
                                                def: 1,
                                                children: 1,
                                                synonyms: $scope.synonymTypes,
                                              })
                            .then(function(response) {
                              $scope.termDetails = response.data;
                            });
                        } else {
                          $scope.termDetails = null;
                        }
                      });

        $scope.gotoChild = function(childId) {
          $scope.gotoChildCallback({ childId: childId });
        };

        $scope.unsetTerm = function() {
          $scope.unsetTermCallback();
        };
        $scope.suggestTerm = function(termSuggestion) {
          $scope.suggestTermCallback(termSuggestion);
        };
        $scope.confirmTerm = function() {
          $scope.confirmTermCallback();
        };

        $scope.openTermSuggestDialog =
          function(featureDisplayName) {
            var suggestInstance = $modal.open({
              templateUrl: app_static_path + 'ng_templates/term_suggest.html',
              controller: 'TermSuggestDialogCtrl',
              title: 'Suggest a new term for ' + featureDisplayName,
              animate: false,
              windowClass: "modal",
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
                ['$modal', 'toaster', 'CantoService', 'CantoConfig', 'CantoGlobals',
                 ontologyTermConfirm]);


var ontologyTermCommentTransfer =
  function(CantoService) {
    return {
      scope: {
        annotationType: '=',
        featureType: '@',
        featureDisplayName: '@',
        annotationDetails: '=',
        comment: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/ontology_term_comment_transfer.html',
    };
  };

canto.directive('ontologyTermCommentTransfer',
                ['CantoService', ontologyTermCommentTransfer]);


function openExtensionPartDialog($modal, extensionPart, relationConfig) {
  return $modal.open({
    templateUrl: app_static_path + 'ng_templates/extension_part_dialog.html',
    controller: 'ExtensionPartDialogCtrl',
    title: 'Edit extension relation',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function() {
        return {
          extensionPart: extensionPart,
          relationConfig: relationConfig,
        }
      },
    },
  }).result;
}


// Filter the extension_configuration results from the server and return
// only those where the "domain" term ID in the configuration matches one of
// subsetIds.  Also ignore any configs where the "role" is "admin" and the
// current, logged in user isn't an admin.
function extensionConfFilter(allConfigs, subsetIds, role) {
  return $.map(allConfigs,
               function(conf) {
                 if (conf.role == 'admin' &&
                     role != 'admin') {
                   return;
                 }
                 if ($.inArray(conf.domain, subsetIds) != -1) {
                   return {
                     displayText: conf.display_text,
                     relation: conf.allowed_relation,
                     range: conf.range,
                     rangeValue: null
                   };
                 }
               });
}


var extensionBuilderDialogCtrl =
  function($scope, $modalInstance, args) {
    $scope.data = args;

    $scope.ok = function () {
      $modalInstance.close({
        extension: $scope.data.extension,
      });
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('ExtensionBuilderDialogCtrl',
                 ['$scope', '$modalInstance', 'args',
                 extensionBuilderDialogCtrl]);


function openExtensionBuilderDialog($modal, extension, termId, featureDisplayName) {
  return $modal.open({
    templateUrl: app_static_path + 'ng_templates/extension_builder_dialog.html',
    controller: 'ExtensionBuilderDialogCtrl',
    title: 'Edit extension',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function() {
        return {
          extension: angular.copy(extension),
          termId: termId,
          featureDisplayName: featureDisplayName,
        };
      },
    },
  }).result;
}


var extensionBuilder =
  function($modal, CantoConfig, CantoService, CursSessionDetails) {
    return {
      scope: {
        extension: '=',
        termId: '@',
        featureDisplayName: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_builder.html',
      controller: function($scope) {
        $scope.extensionConfiguration = [];
        $scope.termDetails = { id: null };

        $scope.asString = function() {
          if ($scope.extension) {
            return $.map($scope.extension,
                         function(part) {
                           return part.relation + '(' + part.rangeValue + ')';
                         }).join(",");
          }

          return '';
        };

        $scope.updateMatchingConfig = function() {
          var subset_ids = $scope.termDetails.subset_ids;

          if ($scope.extensionConfiguration.length > 0 &&
              subset_ids && subset_ids.length > 0) {
            $scope.matchingConfigurations = 
              extensionConfFilter($scope.extensionConfiguration, subset_ids);
            return;
          }

          $scope.matchingConfigurations = [];
        };

        // return the number of uses of each extension config - used to
        // implement the cardinality constraints
        $scope.extensionPartCount = function() {
          var counts = {};

          $.map($scope.extension,
                function(extensionPart) {
                  if (counts[extensionPart.relation]) {
                    counts[extensionPart.relation]++;
                  } else {
                    counts[extensionPart.relation] = 1;
                  }
                });

          return counts;
        };

        $scope.$watch('termId',
                      function(newTermId) {
                        if (newTermId) {
                          CantoService.lookup('ontology', [newTermId],
                                              {
                                                subset_ids: 1,
                                              })
                            .then(function(response) {
                              $scope.termDetails = response.data;
                              CantoConfig.get('extension_configuration')
                                .then(function(results) {
                                  $scope.extensionConfiguration = results.data;
                                  $scope.updateMatchingConfig();
                                });
                            });
                          return;
                        }
                        $scope.termDetails = { id: null };
                    });

        $scope.$watch('extension',
                      function() {
                        $scope.counts = $scope.extensionPartCount();
                      }, true);

        $scope.startAddPart = function(extensionConfig) {
          var editExtensionPart = {
            relation: extensionConfig.relation,
            rangeDisplayName: '',
          };

          var editPromise =
            openExtensionPartDialog($modal, editExtensionPart, extensionConfig);

          editPromise.then(function(result) {
            $scope.extension.push(result.extensionPart);
          });
        };
      },
    };
  };

canto.directive('extensionBuilder',
                ['$modal', 'CantoConfig', 'CantoService', 'CursSessionDetails',
                 extensionBuilder]);


var extensionPartDialogCtrl =
  function($scope, $modalInstance, args) {
    $scope.data = args;

    $scope.isValid = function() {
      return !!$scope.data.extensionPart.rangeValue;
    };

    $scope.ok = function () {
      $modalInstance.close({
        extensionPart: $scope.data.extensionPart,
      });
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('ExtensionPartDialogCtrl',
                 ['$scope', '$modalInstance', 'args',
                 extensionPartDialogCtrl]);


var extensionPartEdit =
  function(CantoService, CursGeneList, toaster) {
    return {
      scope: {
        extensionPart: '=',
        relationConfig: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_part_edit.html',
      controller: function($scope) {
        $scope.rangeGeneId = '';

        $scope.rangeType = $scope.relationConfig.range[0].type;

        $scope.termFoundCallback = function(termId, termName) {
          $scope.extensionPart.rangeValue = termId;
          $scope.extensionPart.rangeDisplayName = termName;
        };
 
        if ($scope.rangeType == 'Gene') {
          if ($scope.extensionPart.rangeValue) {
            // editing existing part
            CursGeneList.geneList().then(function(results) {
              //
            }).catch(function() {
              toaster.pop('note', "couldn't read the gene list from the server");
            });
          } else {
            $scope.extensionPart.rangeValue = '';
          }
        }

        if ($scope.rangeType == 'Ontology') {
          var rangeScope = $scope.relationConfig.range[0].scope;
          if ($.isArray(rangeScope)) {
            $scope.rangeOntologyScope = '[' + rangeScope.join('|') + ']';
          } else {
            // special case for using the ontology namescape instead of
            // restricting to a subset using a term or terms
            $scope.rangeOntologyScope = rangeScope;
          }
          if ($scope.extensionPart.rangeValue) {
          // editing existing extension part
          CantoService.lookup('ontology', [$scope.extensionPart.rangeValue], {})
            .success(function(data) {
              $scope.extensionPart.rangeTermName = data.name;
            });
          }
        }
      }
    };
  };

canto.directive('extensionPartEdit',
                ['CantoService', 'CursGeneList', 'toaster', extensionPartEdit]);


var extensionDisplay =
  function() {
    return {
      scope: {
        extension: '=',
        showDelete: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/extension_display.html',
      controller: function($scope) {
        $scope.deletePart = function(part) {
          if ($scope.showDelete) {
            arrayRemoveOne($scope.extension, part);
          }
        };
      },
    };
  };

canto.directive('extensionDisplay', [extensionDisplay]);


var ontologyWorkflowCtrl =
  function($scope, toaster, $http, AnnotationTypeConfig, CantoService,
           CantoConfig, CursStateService, $attrs) {
    $scope.states = ['searching', 'selectingEvidence', 'buildExtension', 'commenting'];

    CursStateService.setState($scope.states[0]);
    $scope.annotationForServer = null;
    $scope.data = CursStateService;
    $scope.annotationTypeName = $attrs.annotationTypeName;

    $scope.extensionBuilderReady = false;
    $scope.matchingExtensionConfigs = null;

    $scope.updateMatchingConfig = function() {
      var subset_ids = $scope.termDetails.subset_ids;

      if (subset_ids && subset_ids.length > 0) {
        $scope.matchingExtensionConfigs = 
          extensionConfFilter($scope.extensionConfiguration, subset_ids);
        return;
      }

      $scope.matchingExtensionConfigs = [];
    };

    $scope.termFoundCallback =
      function(termId, termName, searchString, matchingSynonym) {
        CursStateService.clearTerm();
        CursStateService.addTerm(termId);
        CursStateService.searchString = searchString;
        CursStateService.matchingSynonym = matchingSynonym;

        $scope.matchingExtensionConfigs = null;

        CantoService.lookup('ontology', [termId],
                            {
                              subset_ids: 1,
                            })
                          .then(function(response) {
                            $scope.termDetails = response.data;
                            CantoConfig.get('extension_configuration')
                              .then(function(results) {
                                $scope.extensionConfiguration = results.data;
                                $scope.updateMatchingConfig();
                              });
                          });
      };

    $scope.gotoChild = function(termId) {
      CursStateService.addTerm(termId);
    };

    $scope.matchingSynonym = function () {
      return CursStateService.matchingSynonym;
    };

    $scope.getState = function() {
      return CursStateService.getState();
    };

    $scope.suggestTerm = function(suggestion) {
      CursStateService.termSuggestion = suggestion;

      $scope.gotoNextState();
    };

    $scope.gotoPrevState = function() {
      CursStateService.setState($scope.prevState());
    };

    $scope.gotoNextState = function() {
      CursStateService.setState($scope.nextState());
    };

    $scope.back = function() {
      if ($scope.getState() == 'searching') {
        CursStateService.clearTerm();
        $scope.extensionBuilderReady = false;
        return;
      }

      if ($scope.getState() == 'commenting') {
        if ($scope.matchingExtensionConfigs &&
            $scope.matchingExtensionConfigs.length == 0) {
          CursStateService.setState('selectingEvidence');
          return;
        }
      }

      $scope.gotoPrevState();
    };

    $scope.proceed = function() {
      if ($scope.getState() == 'commenting') {
        CursStateService.comment = $scope.data.comment;
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

    $scope.prevState = function() {
      var index = $scope.states.indexOf($scope.getState());

      if (index <= 0) {
        return null;
      }

      return $scope.states[index - 1];
    };

    $scope.nextState = function() {
      var index = $scope.states.indexOf($scope.getState());

      if (index == $scope.states.length - 1) {
        return null;
      }

      return $scope.states[index + 1];
    };

    $scope.$watch('getState()',
                  function(newState, oldState) {
                    if (newState == 'commenting') {
                      $scope.annotationForServer =
                        CursStateService.asAnnotationDetails();
                    } else {
                      $scope.annotationForServer = {};
                    }

                    if (oldState == 'selectingEvidence') {
                      CursStateService.evidence_code = $scope.data.evidence_code;
                      CursStateService.with_gene_id = $scope.data.with_gene_id;
                      CursStateService.conditions = $scope.data.conditions;
                    }
                  });

    $scope.currentTerm = function() {
      return CursStateService.currentTerm();
    };

    $scope.isValid = function() {
      if ($scope.getState() == 'selectingEvidence') {
        if ($scope.matchingExtensionConfigs == null) {
          return false;
        }
        return $scope.data.validEvidence;
      }

      return true;
    };

    $scope.storeAnnotation = function() {
      simpleHttpPost(toaster, $http,
                     '../set_term/' + $scope.annotationType.name,
                     CursStateService.asAnnotationDetails());
      toaster.pop('info', 'Creating annotation ...');
    };

    AnnotationTypeConfig.getByName($scope.annotationTypeName)
      .then(function(annotationType) {
        $scope.annotationType = annotationType;
      });
  };

canto.controller('OntologyWorkflowCtrl',
                 ['$scope', 'toaster', '$http', 'AnnotationTypeConfig', 'CantoService',
                  'CantoConfig', 'CursStateService', '$attrs',
                  ontologyWorkflowCtrl]);


var interactionWizardCtrl =
  function($scope, $http, toaster, $attrs) {

    $scope.annotationTypeName = $attrs.annotationTypeName;

    $scope.data = {
      validEvidence: false,
      interactorsConfirmed: false,
    };

    $scope.selectedFeatureIds = [];

    $scope.confirmSelection = function() {
      $scope.data.interactorsConfirmed = true;
    };

    $scope.unconfirmSelection = function() {
      $scope.data.interactorsConfirmed = false;
    };

    $scope.someFeaturesSelected = function() {
      return $scope.selectedFeatureIds.length > 0;
    };

    $scope.isValidEvidence = function() {
      return $scope.data.validEvidence;
    };

    $scope.backToGene = function() {
      history.go(-1);
    };

    $scope.addInteractionAndEvidence = function() {
      $scope.postInProgress = true;
      toaster.pop('info', 'Creating interaction ...');
      simpleHttpPost(toaster, $http, '../add_interaction/' + $scope.annotationTypeName,
                     {
                       evidence_code: $scope.data.evidence_code,
                       prey_gene_ids: $scope.selectedFeatureIds,
                     });
    };
  };

canto.controller('InteractionWizardCtrl',
                 ['$scope', '$http', 'toaster', '$attrs',
                  interactionWizardCtrl]);


var annotationEvidence =
  function(AnnotationTypeConfig, CantoConfig) {
    var directive = {
      scope: {
        evidenceCode: '=',
        conditions: '=',
        withGeneId: '=',
        validEvidence: '=', // true when evidence and with_gene_id are valid
        annotationTypeName: '@',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        $scope.annotationType = null;
        $scope.evidenceCodes = [];

        AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function(annotationType) {
            $scope.annotationType = annotationType;
            $scope.evidenceCodes = annotationType.evidence_codes;
          });

        $scope.isValidEvidenceCode = function() {
          return !!$scope.evidenceCode;
        };

        $scope.isValidWithGene = function() {
          return $scope.evidenceTypes && $scope.evidenceCode &&
            (!$scope.evidenceTypes[$scope.evidenceCode].with_gene || !!$scope.withGeneId);
        };

        $scope.showWith = function() {
          return $scope.evidenceTypes && $scope.isValidEvidenceCode() &&
            $scope.evidenceTypes[$scope.evidenceCode].with_gene;
        };

        $scope.showConditions = function() {
          return $scope.isValidEvidenceCode() &&
            $scope.annotationType && $scope.annotationType.can_have_conditions;
        };

        $scope.isValidCodeAndWith = function() {
          return $scope.isValidEvidenceCode() && $scope.isValidWithGene();
        };

        $scope.validEvidence = $scope.isValidCodeAndWith();

        $scope.getDisplayCode = function(code) {
          if ($scope.evidenceTypes) {
            var name = $scope.evidenceTypes[code].name;
            if (name) {
              if (name.match('^' + code)) {
                return name;
              }
              return name + ' (' + code + ')';
            }
          }

          return code;
        };

        $scope.getDefinition = function(code) {
          if ($scope.evidenceTypes) {
            var def = $scope.evidenceTypes[code].definition;
            if (def) {
              return def;
            }
          }

          return $scope.getDisplayCode(code);
        };

        CantoConfig.get('evidence_types').success(function(results) {
          $scope.evidenceTypes = results;

          $scope.$watch('evidenceCode',
                        function() {
                          if (!$scope.isValidEvidenceCode() ||
                              !$scope.evidenceTypes[$scope.evidenceCode].with_gene) {
                            $scope.withGeneId = undefined;
                          }

                          $scope.validEvidence = $scope.isValidCodeAndWith();
                        });

          $scope.validEvidence = $scope.isValidCodeAndWith();
        });

        $scope.$watch('withGeneId',
                      function() {
                        $scope.validEvidence = $scope.isValidCodeAndWith();
                      });

      },
      templateUrl: app_static_path + 'ng_templates/annotation_evidence.html'
    };
    return directive;
  };

canto.directive('annotationEvidence',
                ['AnnotationTypeConfig', 'CantoConfig', annotationEvidence]);

 var conditionPicker =
   function(CursConditionList, toaster) {
     var directive = {
       scope: {
         conditions: '=',
      },
      restrict: 'E',
      replace: true,
      controller: function($scope) {
        $scope.usedConditions = [];
        $scope.addCondition = function(condName) {
          // this hack stop apply() being called twice when user clicks an add
          // button
          setTimeout(function() {
            $scope.tagitList.tagit("createTag", condName);
          }, 1);
        };
      },
      templateUrl: app_static_path + 'ng_templates/condition_picker.html',
      link: function($scope, elem) {
        var $field = elem.find('.curs-allele-conditions');

        if (typeof($scope.conditions) != 'undefined') {
          CursConditionList.conditionList().then(function(results) {
            $scope.usedConditions = results;

            var updateScopeConditions = function() {
              // apply() is needed so the scope is update when a tag is added in
              // the Tagit field
              $scope.$apply(function() {
                $scope.conditions.length = 0;
                $field.find('li .tagit-label').map(function(index, $elem) {
                  $scope.conditions.push( { name: $elem.textContent.trim() } );
                });
              });
            };

            $field.tagit({
              minLength: 2,
              fieldName: 'curs-allele-condition-names',
              allowSpaces: true,
              placeholderText: 'Type a condition ...',
              tagSource: fetch_conditions,
              autocomplete: {
                focus: ferret_choose.show_autocomplete_def,
                close: ferret_choose.hide_autocomplete_def,
              },
            });
            $.map($scope.conditions,
                  function(cond) {
                    $field.tagit("createTag", cond.name);
                  });

            // don't start updating until all initial tags are added
            $field.tagit({
              afterTagAdded: updateScopeConditions,
              afterTagRemoved: updateScopeConditions,
            });

            $scope.tagitList = $field;
          }).catch(function() {
            toaster.pop('error', "couldn't read the condition list from the server");
          });
        }
      }
    };

    return directive;
  };

canto.directive('conditionPicker', ['CursConditionList', 'toaster', conditionPicker]);

var alleleNameComplete =
  function(CursAlleleList, toaster) {
    var directive = {
      scope: {
        allelePrimaryIdentifier: '=',
        alleleName: '=',
        alleleDescription: '=',
        alleleType: '=',
        geneIdentifier: '@',
      },
      restrict: 'E',
      replace: true,
      template: '<span><input ng-model="alleleName" type="text" class="curs-allele-name aform-control" value=""/></span>',
      controller: function ($scope) {
        $scope.clicked = function () {
          $scope.merge = $scope.alleleDescription + ' ' + $scope.allelePrimaryIdentifier;
        };
      },
      link: function(scope, elem) {
        var processResponse = function(lookupResponse) {
          return $.map(
            lookupResponse,
            function(el) {
              return {
                value: el.name,
                allele_primary_identifier: el.uniquename,
                display_name: el.display_name,
                description: el.description,
                type: el.type,
              };
            });
        };
        elem.find('input').autocomplete({
          source: function(request, response) {
            CursAlleleList.alleleList(scope.geneIdentifier, request.term)
              .then(function(lookupResponse) {
                response(processResponse(lookupResponse));
              })
            .catch(function() {
              toaster.pop("failed to lookup allele of: " + scope.geneName);
            });
          },
          select: function(event, ui) {
            scope.$apply(function() {
            if (typeof(ui.item.allele_primary_identifier) === 'undefined') {
              scope.allelePrimaryIdentifier = '';
            } else {
              scope.allelePrimaryIdentifier = ui.item.allele_primary_identifier;
            }
            scope.alleleType = ui.item.type;
            if (typeof(ui.item.label) === 'undefined') {
              scope.alleleName = '';
            } else {
              scope.alleleName = ui.item.label;
            }
            if (typeof(ui.item.description) === 'undefined') {
              scope.alleleDescription = '';
            } else {
              scope.alleleDescription = ui.item.description;
            }
            });
          }
        }).data("autocomplete" )._renderItem = function(ul, item) {
          return $( "<li></li>" )
            .data( "item.autocomplete", item )
            .append( "<a>" + item.display_name + "</a>" )
            .appendTo( ul );
        };
      }
    };

    return directive;
  };

canto.directive('alleleNameComplete', ['CursAlleleList', 'toaster', alleleNameComplete]);


var alleleEditDialogCtrl =
  function($scope, $modalInstance, CantoConfig, args) {
    $scope.config = {
      endogenousWildtypeAllowed: args.endogenousWildtypeAllowed,
    };
    $scope.alleleData = {};
    copyObject(args.allele, $scope.alleleData);
    $scope.alleleData.primary_identifier = $scope.alleleData.primary_identifier || '';
    $scope.alleleData.name = $scope.alleleData.name || '';
    $scope.alleleData.description = $scope.alleleData.description || '';
    $scope.alleleData.type = $scope.alleleData.type || '';
    $scope.alleleData.expression = $scope.alleleData.expression || '';
    $scope.alleleData.evidence = $scope.alleleData.evidence || '';

    $scope.env = {
    };

    $scope.name_autopopulated = false;

    $scope.env.allele_type_names_promise = CantoConfig.get('allele_type_names');
    $scope.env.allele_types_promise = CantoConfig.get('allele_types');

    $scope.env.allele_type_names_promise.then(function(response) {
      $scope.env.allele_type_names = response.data;
    });

    $scope.env.allele_types_promise.then(function(response) {
      $scope.env.allele_types = response.data;
    });

    $scope.maybe_autopopulate = function() {
      if (typeof this.current_type_config === 'undefined') {
        return '';
      }
      var autopopulate_name = this.current_type_config.autopopulate_name;
      if (typeof(autopopulate_name) === 'undefined') {
        return '';
      }

      $scope.alleleData.name =
        autopopulate_name.replace(/@@gene_display_name@@/, $scope.alleleData.gene_display_name);
      return this.alleleData.name;
    };

    $scope.$watch('alleleData.type',
                  function(newType, oldType) {
                    $scope.env.allele_types_promise.then(function(response) {
                      $scope.current_type_config = response.data[newType];

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
                  });

    $scope.isValidType = function() {
      return !!$scope.alleleData.type;
    };

    $scope.isValidName = function() {
      return !$scope.current_type_config || !$scope.current_type_config.allele_name_required || $scope.alleleData.name;
    };

    $scope.isValidDescription = function() {
      return !$scope.current_type_config || !$scope.current_type_config.description_required || $scope.alleleData.description;
    };

    $scope.isValidExpression = function() {
      return $scope.current_type_config &&
        (!$scope.current_type_config.expression_required ||
         $scope.alleleData.expression);
    };

    $scope.isExistingAllele = function() {
      return !!$scope.alleleData.primary_identifier;
    };

    $scope.isValid = function() {
      return $scope.isExistingAllele() ||
        ($scope.isValidType() && $scope.isValidName() &&
         $scope.isValidDescription() && $scope.isValidExpression());
    };

    $scope.ok = function () {
      copyObject($scope.alleleData, args.allele);
      $modalInstance.close(args.allele);
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('AlleleEditDialogCtrl',
                 ['$scope', '$modalInstance',
                  'CantoConfig', 'args',
                 alleleEditDialogCtrl]);

var termSuggestDialogCtrl =
  function($scope, $modalInstance) {
    $scope.suggestion = {
      name: '',
      definition: '',
    };

    $scope.isValidName = function() {
      return $scope.suggestion.name;
    };

    $scope.isValidDefinition = function() {
      return $scope.suggestion.definition;
    };

    $scope.isValid = function() {
      return $scope.isValidName() && $scope.isValidDefinition();
    };

    // return the data from the dialog as an Object
    $scope.dialogToData = function($scope) {
      return {
        name: $scope.suggestion.name,
        definition: $scope.suggestion.definition,
      };
    };

    $scope.ok = function () {
      $modalInstance.close($scope.dialogToData($scope));
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('TermSuggestDialogCtrl',
                 ['$scope', '$modalInstance',
                 termSuggestDialogCtrl]);


function storeGenotype(toaster, $http, genotype_id, genotype_name, genotype_background, alleles,
                       followLocation) {
  var url = curs_root_uri + '/feature/genotype';

  if (genotype_id) {
    url += '/edit/' + genotype_id;
  } else {
    url += '/store';
  }

  var data = {
    genotype_name: genotype_name,
    genotype_background: genotype_background,
    alleles: alleles,
  };

  loadingStart();

  var result = $http.post(url, data);

  result.finally(loadingEnd);

  if (followLocation) {
    result.success(function(data) {
      if (data.status == "success" || data.status == "existing") {
        window.location.href = data.location;
      } else {
        toaster.pop('error', data.message);
      }
    }).
    error(function(data, status){
      toaster.pop('error', "Accessing server failed: " + (data || status) );
    });
  }

  return result;
}

function makeAlleleEditInstance($modal, allele, endogenousWildtypeAllowed)
{
  return $modal.open({
    templateUrl: app_static_path + 'ng_templates/allele_edit.html',
    controller: 'AlleleEditDialogCtrl',
    title: 'Add an allele for this phenotype',
    animate: false,
    windowClass: "modal",
    resolve: {
      args: function() {
        return {
          endogenousWildtypeAllowed: endogenousWildtypeAllowed,
          allele: allele,
        };
      }
    }
  });
}


var genePageCtrl =
  function($scope, $modal, toaster, $http) {
    $scope.singleAlleleQuick = function(gene_display_name, gene_systematic_id, gene_id) {
      var editInstance = makeAlleleEditInstance($modal,
                                                {
                                                  gene_display_name: gene_display_name,
                                                  gene_systematic_id: gene_systematic_id,
                                                  gene_id: gene_id,
                                                });

      editInstance.result.then(function (alleleData) {
        storeGenotype(toaster, $http, undefined, undefined, undefined, [alleleData], true);
      });
    };
  };

canto.controller('GenePageCtrl', ['$scope', '$modal', 'toaster', '$http', genePageCtrl]);


var singleGeneAddDialogCtrl =
  function($scope, $modalInstance, $q, toaster, CantoService, Curs) {
    $scope.gene = {
      searchIdentifier: '',
      message: null,
      valid: false,
    };

    $scope.isValid = function() {
      return $scope.gene.primaryIdentifier != null;
    };

    var cancelPromise = null;

    $scope.$watch('gene.searchIdentifier',
                  function() {
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

                      promise.success(function(data) {
                        if (data.missing.length > 0) {
                          $scope.gene.message = 'Not found';
                          $scope.gene.primaryIdentifier = null;
                        } else {
                          if (data.found.length > 1) {
                            $scope.gene.message =
                              'There is more than one gene matching gene: ' +
                              $.map(data.found,
                                    function(gene) {
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

      promise.success(function(data) {
        if (data.status === 'error') {
          toaster.pop('error', data.message);
        } else {
          if (data.gene_id == null) {
            // null if the gene was already in the list
            toaster.pop('info', $scope.gene.primaryIdentifier +
                        ' is already added to this session');
          }
          $modalInstance.close({
            new_gene_id: data.gene_id,
          });
        }
      })
      .error(function() {
        toaster.pop('error', 'Failed to add gene, could not contact the Canto server');
      });
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('SingleGeneAddDialogCtrl',
                 ['$scope', '$modalInstance', '$q', 'toaster', 'CantoService', 'Curs',
                 singleGeneAddDialogCtrl]);

var multiAlleleCtrl =
  function($scope, $http, $modal, CantoConfig, Curs, toaster) {
  $scope.getGenesFromServer = function() {
    Curs.list('gene').success(function(results) {
      $scope.genes = results;

      $.map($scope.genes,
            function(gene) {
              gene.display_name = gene.primary_name || gene.primary_identifier;
            });
    }).error(function() {
      toaster.pop('failed to get gene list from server');
    });
  };

  $scope.genes = [
  ];

  $scope.reset = function() {
    $scope.alleles = [
    ];

    $scope.getGenesFromServer();

    $scope.data = {
      genotype_long_name: '',
      genotype_name: '',
      addAnother: false,
    };
  };

  $scope.reset();

  $scope.env = {
    curs_config_promise: CantoConfig.get('curs_config')
  };

  $scope.init_from = function(genotype_id) {
    Curs.details('genotype', ['by_id', genotype_id])
      .success(function(genotype_details) {
        $scope.alleles = genotype_details.alleles;
        $scope.data.genotype_name = genotype_details.name;
        $scope.data.genotype_background = genotype_details.background;
      });
  };

  $scope.init = function(edit_or_duplicate, genotype_id) {
    if (genotype_id) {
      if (edit_or_duplicate === 'edit') {
        $scope.data.genotype_id = genotype_id;
        $scope.isEditing = true;
      } else {
        $scope.isEditing = false;
      }
      $scope.init_from(genotype_id);
    }
  };

  $scope.$watch('alleles',
                function() {
                  $scope.env.curs_config_promise.then(function(response) {
                    $scope.data.genotype_long_name =
                      response.data.genotype_config.default_strain_name +
                      " " +
                      $.map($scope.alleles, function(val) {
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
                },
                true);

  $scope.store = function() {
    var result =
      storeGenotype(toaster, $http, $scope.data.genotype_id,
                    $scope.data.genotype_name, $scope.data.genotype_background,
                    $scope.alleles, !$scope.data.addAnother);

    result.success(function(data) {
      if (data.status === "success") {
        toaster.pop('info', "Created new genotype: " + data.genotype_display_name);
        $scope.reset();
      } else {
        if (data.status === "existing") {
          toaster.pop('info', "Using existing genotype: " + data.genotype_display_name);
          $scope.reset();
        } else {
          toaster.pop('error', data.message);
        }
      }
    }).
    error(function(data, status){
      toaster.pop('error', "Accessing server failed: " + (data || status) );
    });
  };

  $scope.removeAllele = function (allele) {
    $scope.alleles.splice($scope.alleles.indexOf(allele), 1);
  };

  $scope.openAlleleEditDialog =
    function(allele) {
      var endogenousWildtypeAllowed = false;

      if (allele.gene) {
        allele.gene_display_name = allele.gene.display_name;
        allele.gene_systematic_id = allele.gene.primary_identifier;
        allele.gene_id = allele.gene.gene_id;
        delete allele.gene;
      }

      // see: https://sourceforge.net/p/pombase/curation-tool/782/
      // and: https://sourceforge.net/p/pombase/curation-tool/576/
      $.map($scope.alleles,
            function(existingAllele) {
              if (existingAllele.gene_id == allele.gene_id) {
                endogenousWildtypeAllowed = true;
              }
            });

      var editInstance =
        makeAlleleEditInstance($modal, allele, endogenousWildtypeAllowed);

      editInstance.result.then(function (editedAllele) {
        if ($scope.alleles.indexOf(editedAllele) < 0) {
          $scope.alleles.push(editedAllele);
        }
      });
    };

  $scope.openSingleGeneAddDialog = function() {
    var modal = openSingleGeneAddDialog($modal);
    modal.result.then(function () {
      $scope.getGenesFromServer();
    });
  };

  $scope.cancel = function() {
    window.location.href = curs_root_uri + '/genotype_manage';
  };

  $scope.isValid = function() {
    return $scope.alleles.length > 0;
  };
};

canto.controller('MultiAlleleCtrl', ['$scope', '$http', '$modal', 'CantoConfig', 'Curs', 'toaster',
                                     multiAlleleCtrl]);


var genotypeViewCtrl =
  function($scope) {
    $scope.init = function(annotationCount) {
      $scope.annotationCount = annotationCount;
    };
  };

canto.controller('GenotypeViewCtrl',
                 ['$scope',
                 genotypeViewCtrl]);


var GenotypeManageCtrl =
  function($scope, CursGenotypeList, CantoGlobals, toaster) {
    $scope.app_static_path = CantoGlobals.app_static_path;

    $scope.data = {
      genotypeSearching: false,
      genotypes: [],
      waitingForServer: true,
    };

    $scope.startSearch = function() {
      $scope.data.genotypeSearching = true;
    };

    $scope.cancelSearch = function() {
      $scope.data.genotypeSearching = false;
    };

    CursGenotypeList.cursGenotypeList().then(function(results) {
      $scope.data.genotypes = results;
      $scope.data.waitingForServer = false;
    }).catch(function() {
      toaster.pop('error', "couldn't read the genotype list from the server");
      $scope.data.waitingForServer = false;
    });
  };

canto.controller('GenotypeManageCtrl',
                 ['$scope', 'CursGenotypeList', 'CantoGlobals', 'toaster',
                 GenotypeManageCtrl]);

var geneSelectorCtrl =
  function(CursGeneList, $modal, toaster) {
    return {
      scope: {
        selectedGenes: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/gene_selector.html',
      controller: function($scope) {
        $scope.data = {
          genes: [],
        };

        function getGenesFromServer() {
          CursGeneList.geneList().then(function(results) {
            $scope.data.genes = results;
          }).catch(function() {
            toaster.pop('note', "couldn't read the gene list from the server");
          });
        }

        getGenesFromServer();

        $scope.addAnotherGene = function() {
          var modal = openSingleGeneAddDialog($modal);
          modal.result.then(function () {
            getGenesFromServer();
          });
        };

      },
      link: function(scope) {
        scope.selectedGenesFilter = function() {
          scope.selectedGenes = $.grep(scope.data.genes, function(gene) {
            return gene.selected;
          });
        };
      },
    };
  };

canto.directive('geneSelector',
                ['CursGeneList', '$modal', 'toaster',
                  geneSelectorCtrl]);

var genotypeSearchCtrl =
  function(CursGenotypeList, CantoGlobals) {
    return {
      scope: {
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_search.html',
      controller: function($scope) {
        $scope.data = {
          filteredCursGenotypes: [],
          filteredExternalGenotypes: [],
          searchGenes: [],
          waitingForServerCurs: false,
          waitingForServerExternal: false,
        };
        $scope.app_static_path = CantoGlobals.app_static_path;

        $scope.addGenotype = function() {
          window.location.href = CantoGlobals.curs_root_uri + '/feature/genotype/add';
        };

        $scope.waitingForServer = function() {
          return $scope.data.waitingForServerCurs || $scope.data.waitingForServerExternal;
        };

        $scope.filteredGenotypeCount = function() {
          return $scope.data.filteredCursGenotypes.length +
            $scope.data.filteredExternalGenotypes.length;
        };
      },
      link: function(scope) {
        scope.$watch('data.searchGenes',
                      function() {
                        if (scope.data.searchGenes.length == 0) {
                          scope.data.filteredCursGenotypes.length = 0;
                          scope.data.filteredExternalGenotypes.length = 0;
                        } else {
                          scope.data.waitingForServerCurs = true;
                          scope.data.waitingForServerExternal = true;
                          var geneIdentifiers = $.map(scope.data.searchGenes,
                                                      function(gene_data) {
                                                        return gene_data.primary_identifier;

                                                      });
                          CursGenotypeList.filteredGenotypeList('curs_only', {
                            gene_identifiers: geneIdentifiers
                          }).then(function(results) {
                            scope.data.filteredCursGenotypes = results;
                            scope.data.waitingForServerCurs = false;
                            delete scope.data.serverError;
                          }).catch(function() {
                            scope.data.waitingForServerCurs = false;
                            scope.data.serverError = "couldn't read the genotype list from the server";
                          });
                          CursGenotypeList.filteredGenotypeList('external_only', {
                            gene_identifiers: geneIdentifiers
                          }).then(function(results) {
                            scope.data.filteredExternalGenotypes = results;
                            scope.data.waitingForServerExternal = false;
                            delete scope.data.serverError;
                          }).catch(function() {
                            scope.data.waitingForServerExternal = false;
                            scope.data.serverError = "couldn't read the genotype list from the server";
                          });
                        }
                      });
      },
    };
  };

canto.directive('genotypeSearch',
                 ['CursGenotypeList', 'CantoGlobals',
                  genotypeSearchCtrl]);

var genotypeListRowCtrl =
  function(toaster, CantoGlobals, CursGenotypeList) {
    return {
      restrict: 'A',
      replace: true,
      templateUrl: CantoGlobals.app_static_path + 'ng_templates/genotype_list_row.html',
      controller: function($scope) {
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.read_only_curs = CantoGlobals.read_only_curs;

        $scope.deleteGenotype = function() {
          loadingStart();

          // using $parent is brittle
          var q = CursGenotypeList.deleteGenotype($scope.$parent.genotypeList, $scope.genotype);

          q.then(function() {
            toaster.pop('success', 'Genotype deleted');
          });

          q.catch(function(message) {
            if (message.match('genotype .* has annotations')) {
              toaster.pop('warning', "couldn't delete the genotype: delete the annotations that use it first");
            } else {
              toaster.pop('error', "couldn't delete the genotype: " + message);
            }
          });

          q.finally(function() {
            loadingEnd();
          });
        };
      },
    };
  };

canto.directive('genotypeListRow',
                ['toaster', 'CantoGlobals', 'CursGenotypeList', genotypeListRowCtrl]);


var genotypeListViewCtrl =
  function() {
    return {
      scope: {
        genotypeList: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/genotype_list_view.html',
    };
  };

canto.directive('genotypeListView',
                 [genotypeListViewCtrl]);


var singleGeneGenotypeList =
  function(CursGenotypeList, CantoGlobals) {
    return {
      scope: {
        genePrimaryIdentifier: '=',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/single_gene_genotype_list.html',
      controller: function($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.data = {
          filteredGenotypes: [],
          waitingForServer: true,
          showAll: false,
        };

        $scope.shouldShowAll = function() {
          return $scope.data.showAll;
        };

        $scope.showAll = function() {
          $scope.data.showAll = true;
        };

        $scope.hideAll = function() {
          $scope.data.showAll = false;
        };

        CursGenotypeList.filteredGenotypeList('curs_only', {
          gene_identifiers: [$scope.genePrimaryIdentifier],
        }).then(function(results) {
          $scope.data.filteredGenotypes = results;
          $scope.data.waitingForServer = false;
          if (results.length > 0 && results.length <= 5) {
            $scope.data.showAll = true;
          }
          delete $scope.data.serverError;
        }).catch(function() {
          $scope.data.waitingForServer = false;
          $scope.data.serverError = "couldn't read the genotype list from the server";
        });

      },
    };
  };

canto.directive('singleGeneGenotypeList',
                ['CursGenotypeList', 'CantoGlobals', singleGeneGenotypeList]);


var EditDialog = function($) {
  function confirm($dialog) {
    var $form = $('#curs-edit-dialog form');
    $dialog.dialog('close');
    $('#loading').unbind('ajaxStop.canto');
    $form.ajaxSubmit({
          dataType: 'json',
          success: function() {
            $dialog.dialog("destroy");
            var $dialog_div = $('#curs-edit-dialog');
            $dialog_div.remove();
            window.location.reload(false);
          }
        });
  }

  function cancel() {
    $(this).dialog("destroy");
    var $dialog_div = $('#curs-edit-dialog');
    $dialog_div.remove();
  }

  function create(title, current_comment, form_url) {
    var $dialog_div = $('#curs-edit-dialog');
    if ($dialog_div.length) {
      $dialog_div.remove();
    }

    var dialog_html =
      '<div id="curs-edit-dialog" style="display: none">' +
      '<form action="' + form_url + '" method="post">' +
      '<textarea rows="8" cols="70" name="curs-edit-dialog-text">' + current_comment +
      '</textarea></form></div>';

    $dialog_div = $(dialog_html);

    var $dialog = $dialog_div.dialog({
      modal: true,
      autoOpen: true,
      height: 'auto',
      width: 600,
      title: title,
      buttons : [
                 {
                   text: "Cancel",
                   click: cancel,
                 },
                 {
                   text: "Edit",
                   click: function() {
                     confirm($dialog);
                   },
                 },
                ]
    });

    return $dialog;
  }

  return {
    create: create
  };
}($);

canto.service('CantoConfig', function($http) {
  this.promises = {};

  this.get = function(key) {
    if (!this.promises[key]) {
      this.promises[key] =
        $http({method: 'GET',
               url: canto_root_uri + 'ws/canto_config/' + key});
    }
    return this.promises[key];
  };
});

canto.service('AnnotationTypeConfig', function(CantoConfig, $q) {
  this.getAll = function() {
    if (typeof(this.listPromise) === 'undefined') {
      this.listPromise = CantoConfig.get('annotation_type_list');
    }

    return this.listPromise;
  };
  this.getByKeyValue = function(key, value) {
    var q = $q.defer();

    this.getAll().success(function(annotationTypeList) {
      var filteredAnnotationTypes =
        $.grep(annotationTypeList,
               function(annotationType) {
                 return annotationType[key] === value;
               });
      if (filteredAnnotationTypes.length > 0){
        q.resolve(filteredAnnotationTypes[0]);
      } else {
        q.resolve(undefined);
      }
    }).error(function(data, status) {
      if (status) {
        q.reject();
      } // otherwise the request was cancelled
    });

    return q.promise;

  };
  this.getByName = function(typeName) {
    return this.getByKeyValue('name', typeName);
  };
  this.getByNamespace = function(namespace) {
    return this.getByKeyValue('namespace', namespace);
  };
});


function UploadGenesCtrl($scope) {
  $scope.data = {
    geneIdentifiers: '',
    noAnnotation: false,
    noAnnotationReason: '',
    otherText: '',
    geneList: '',
  };
  $scope.isValid = function() {
    return $scope.data.geneIdentifiers.length > 0 ||
      ($scope.data.noAnnotation &&
       $scope.data.noAnnotationReason.length > 0 &&
       ($scope.data.noAnnotationReason !== "Other" ||
        $scope.data.otherText.length > 0));
  };
}

canto.controller('UploadGenesCtrl', UploadGenesCtrl);


function SubmitToCuratorsCtrl($scope) {
  $scope.data = {
    reason: null,
    otherReason: '',
    hasAnnotation: false
  };
  $scope.noAnnotationReasons = [];

  $scope.init = function(reasons) {
    $scope.noAnnotationReasons = reasons;
  };

  $scope.validReason = function() {
    return $scope.data.reason != null && $scope.data.reason.length > 0 &&
      ($scope.data.reason !== 'Other' || $scope.data.otherReason.length > 0);
  };
}

canto.controller('SubmitToCuratorsCtrl', SubmitToCuratorsCtrl);

var termConfirmDialogCtrl =
  function($scope, $modalInstance, CantoService, CantoGlobals, args) {
    $scope.app_static_path = CantoGlobals.app_static_path;

    $scope.data = {
      initialTermId: args.termId,
      state: 'definition',
      termDetails: null,
    };

    $scope.setTerm = function(termId) {
      var promise = CantoService.lookup('ontology', [termId],
                                        {
                                          def: 1,
                                          children: 1,
                                        });

      promise.success(function(termDetails) {
        $scope.data.termDetails = termDetails;

        if (args.initialState) {
          $scope.data.state = args.initialState;
          delete args.initialState;
        } else {
          $scope.data.state = 'definition';
        }
      });
    };

    $scope.setTerm($scope.data.initialTermId);

    $scope.gotoChild = function(childId) {
      $scope.setTerm(childId);
    };

    $scope.next = function() {
      $scope.data.state = 'children';
    };

    $scope.back = function() {
      $scope.data.state = 'definition';
    };

    $scope.finish = function() {
      $modalInstance.close({ newTermId: $scope.data.termDetails.id,
                             newTermName: $scope.data.termDetails.name });
    };

    $scope.cancel = function() {
      $modalInstance.dismiss('cancel');
    };
  };


canto.controller('TermConfirmDialogCtrl',
                 ['$scope', '$modalInstance', 'CantoService', 'CantoGlobals', 'args',
                  termConfirmDialogCtrl]);


function openTermConfirmDialog($modal, termId, initialState)
{
  return $modal.open({
    templateUrl: app_static_path + 'ng_templates/term_confirm.html',
    controller: 'TermConfirmDialogCtrl',
    title: 'Confirm term',
    animate: false,
    windowClass: "modal",
    size: 'lg',
    resolve: {
      args: function() {
        return {
          termId: termId,
          initialState: initialState,
        };
      }
    },
  });
}


var termDefinitionDisplayCtrl =
  function() {
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
  function(CantoGlobals) {
    return {
      scope: {
        termDetails: '=',
        gotoChildCallback: '&',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/term_children.html',
      controller: function($scope) {
        $scope.CantoGlobals = CantoGlobals;
        $scope.gotoChild = function(childId) {
          $scope.gotoChildCallback({ childId: childId });
        };
      },
    };
  };

canto.directive('termChildrenDisplay',
                ['CantoGlobals',
                 termChildrenDisplayCtrl]);


var annotationEditDialogCtrl =
  function($scope, $modal, $modalInstance, AnnotationProxy, AnnotationTypeConfig,
           CursSessionDetails, CantoService, toaster, args) {
    $scope.annotation = { conditions: [] };
    $scope.annotationTypeName = args.annotationTypeName;
    $scope.currentFeatureDisplayName = args.currentFeatureDisplayName;
    $scope.newlyAdded = args.newlyAdded;
    $scope.featureEditable = args.featureEditable;
    $scope.status = {
      validEvidence: false
    };

    copyObject(args.annotation, $scope.annotation);

    $scope.isValidFeature = function() {
      return $scope.annotation.feature_id;
    };

    $scope.isValidInteractingGene = function() {
      return $scope.annotation.interacting_gene_id;
    };

    $scope.isValidTerm = function() {
      return $scope.annotation.term_ontid;
    };

    $scope.isValidEvidence = function() {
      return $scope.status.validEvidence;
    };

    $scope.isValid = function() {
      if ($scope.annotationType.category === 'ontology') {
        return $scope.isValidFeature() &&
          $scope.isValidTerm() && $scope.isValidEvidence();
      }
      return $scope.isValidFeature() &&
        $scope.isValidInteractingGene() && $scope.isValidEvidence();
    };

    $scope.termFoundCallback =
      function(termId, termName, searchString) {
        $scope.annotation.term_ontid = termId;
        $scope.annotation.term_name = termName;

        if (!searchString.match(/^".*"$/) && searchString !== termId) {
          var termConfirm = openTermConfirmDialog($modal, termId);

          termConfirm.result.then(function(result) {
            $scope.annotation.term_ontid = result.newTermId;
            $scope.annotation.term_name = result.newTermName;
          });
        } // else: user pasted a term ID or user quoted the search - skip confirmation
      };

    $scope.editExtension = function() {
      var editPromise =
        openExtensionBuilderDialog($modal, $scope.annotation.extension,
                                   $scope.annotation.term_ontid,
                                   $scope.currentFeatureDisplayName);

      editPromise.then(function(result) {
        angular.copy(result.extension, $scope.annotation.extension);
      });
    };

    $scope.ok = function() {
      var q = AnnotationProxy.storeChanges(args.annotation,
                                           $scope.annotation, args.newlyAdded);
      loadingStart();
      toaster.pop('info', 'Storing annotation ...');
      q.then(function(annotation) {
        $modalInstance.close(annotation);
      })
      .catch(function(message) {
        toaster.pop('error', message);
        $modalInstance.dismiss();
      })
      .finally(function() {
        loadingEnd();
      });
    };

    $scope.cancel = function() {
      $modalInstance.dismiss('cancel');
    };

    CursSessionDetails.get()
      .success(function(sessionDetails) {
        $scope.curatorDetails = sessionDetails.curator;
      });

    CantoService.details('user')
      .success(function(user) {
        $scope.userDetails = user.details;
      });

    AnnotationTypeConfig.getByName($scope.annotationTypeName)
      .then(function(annotationType) {
        $scope.annotationType = annotationType;
        $scope.displayAnnotationFeatureType = capitalizeFirstLetter(annotationType.feature_type);
        $scope.annotation.feature_type = annotationType.feature_type;

        if (! annotationType.can_have_conditions) {
          delete $scope.annotation.conditions;
        }
      });
  };


canto.controller('AnnotationEditDialogCtrl',
                 ['$scope', '$modal', '$modalInstance', 'AnnotationProxy',
                  'AnnotationTypeConfig', 'CursSessionDetails', 'CantoService',
                  'toaster', 'args',
                  annotationEditDialogCtrl]);



function startEditing($modal, annotationTypeName, annotation,
                      currentFeatureDisplayName, newlyAdded, featureEditable) {
  var editInstance = $modal.open({
    templateUrl: app_static_path + 'ng_templates/annotation_edit.html',
    controller: 'AnnotationEditDialogCtrl',
    title: 'Edit this annotation',
    animate: false,
    size: 'lg',
    resolve: {
      args: function() {
        return {
          annotation: annotation,
          annotationTypeName: annotationTypeName,
          currentFeatureDisplayName: currentFeatureDisplayName,
          newlyAdded: newlyAdded,
          featureEditable: featureEditable,
       };
      }
    }
  });

  return editInstance.result;
}


function makeNewAnnotation(template) {
  var copy = {};
  copyObject(template, copy);
  copy.newly_added = true;
  return copy;
}


function addAnnotation($modal, annotationTypeName, featureType, featureId,
                       featureDisplayName) {
  var template = {
    annotation_type: annotationTypeName,
    feature_type: featureType,
  };
  if (featureId) {
    template.feature_id = featureId;
  }
  var featureEditable = !featureId;
  var newAnnotation = makeNewAnnotation(template);
  startEditing($modal, annotationTypeName, newAnnotation,
               featureDisplayName, true, featureEditable);
}

var annotationQuickAdd =
  function($modal, CursSettings, CantoGlobals) {
    return {
      scope: {
        annotationTypeName: '@',
        featureType: '@',
        featureId: '@',
        featureDisplayName: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_quick_add.html',
      controller: function($scope) {
        $scope.read_only_curs = CantoGlobals.read_only_curs;

        $scope.enabled = function() {
          return CursSettings.getAnnotationMode() == 'advanced';
        };

        $scope.add = function() {
          addAnnotation($modal, $scope.annotationTypeName, $scope.featureType,
                        $scope.featureId, $scope.featureDisplayName);
        };
      },
    };
  };

canto.directive('annotationQuickAdd', ['$modal', 'CursSettings', 'CantoGlobals', annotationQuickAdd]);


function filterAnnotations(annotations, params) {
  return annotations.filter(function(annotation) {
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
          if (typeof(annotation.interacting_gene_id) !== 'undefined' &&
              annotation.interacting_gene_id == params.featureId) {
            return true;
          }
          if (annotation.alleles !== undefined &&
              $.grep(annotation.alleles,
                     function(alleleData) {
                       return alleleData.gene_id.toString() === params.featureId;
                     }).length > 0) {
            return true;
          }
        }
        if (params.featureType === 'genotype' &&
            annotation.genotype_id == params.featureId) {
          return true;
        }
      }
    }
    return false;
  });
}


var annotationTableCtrl =
  function(CantoGlobals, AnnotationProxy, AnnotationTypeConfig, CursGenotypeList,
           CursSessionDetails, CantoConfig) {
    return {
      scope: {
        featureIdFilter: '@',
        featureTypeFilter: '@',
        featureStatusFilter: '@',
        featureFilterDisplayName: '@',
        alleleCountFilter: '@',
        annotationTypeName: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_table.html',
      controller: function($scope) {
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.app_static_path = CantoGlobals.app_static_path;

        $scope.multiOrganismMode = false;

        $scope.filterParams = {
          annotationTypeName: $scope.annotationTypeName,
          featureId: $scope.featureIdFilter,
          featureStatus: $scope.featureStatusFilter,
          featureType: $scope.featureTypeFilter,
          alleleCount: $scope.alleleCountFilter,
        };

        $scope.data = {};

        $scope.$watch('data.annotations',
                      function(newAnnotations) {
                        if (newAnnotations) {
                          $scope.data.filteredAnnotations =
                            filterAnnotations(newAnnotations, $scope.filterParams);
                          $scope.updateColumns();
                        } else {
                          $scope.data.filteredAnnotations = [];
                        }
                      },
                      true);

        var initialHideColumns = {      // columns to hide because they're empty
          with_or_from_identifier: true,  // set to false when a row has a non empty element
          qualifiers: true,
          submitter_comment: true,
          extension: true,
          curator: true,
          genotype_name: true,
          genotype_background: true,
          term_suggestion: true,
        };

        $scope.data = {
          hasFeatures: false, // set to true if there are feature of type featureTypeFilter
          annotations: null,
          hideColumns: {},
          publicationUniquename: null,
          filteredAnnotations: [],
        };

        CursSessionDetails.get()
          .success(function(sessionDetails) {
            $scope.data.publicationUniquename = sessionDetails.publication_uniquename;
          });

        CantoConfig.get('instance_organism').success(function(results) {
          if (!results.taxonid) {
            $scope.multiOrganismMode = true;
          }
        });

        copyObject(initialHideColumns, $scope.data.hideColumns);

        $scope.updateColumns = function() {
          if ($scope.data.filteredAnnotations) {
            copyObject(initialHideColumns, $scope.data.hideColumns);
            $.map($scope.data.annotations,
                  function(annotation) {
                    $.map(initialHideColumns,
                          function(prop, key) {
                            if (key == 'qualifiers' && annotation.is_not) {
                              $scope.data.hideColumns[key] = false;
                            }
                            if (key == 'term_suggestion') {
                              if (annotation.term_suggestion_name || annotation.term_suggestion_definition) {
                                $scope.data.hideColumns[key] = false;
                              }
                            }
                            if (annotation[key] &&
                                (!$.isArray(annotation[key]) || annotation[key].length > 0)) {
                              $scope.data.hideColumns[key] = false;
                            }
                          });
                  });
          }
        };
      },
      link: function(scope) {
        scope.data.annotations = null;
        AnnotationProxy.getAnnotation(scope.annotationTypeName)
          .then(function(annotations) {
            scope.data.annotations = annotations;
          }).catch(function() {
            scope.data.serverError = "couldn't read annotations from the server";
          });

        AnnotationTypeConfig.getByName(scope.annotationTypeName).then(function(annotationType) {
          scope.annotationType = annotationType;
          scope.displayAnnotationFeatureType = capitalizeFirstLetter(annotationType.feature_type);

          if (annotationType.feature_type === 'genotype') {
            CursGenotypeList.cursGenotypeList().then(function(results) {
              scope.data.hasFeatures = (results.length > 0);
            }).catch(function() {
              scope.data.serverError = "couldn't read the genotype list from the server";
            });
          } else {
            // if we're here the user has some genes in their list
            scope.data.hasFeatures = true;
          }
        });
      }
    };
  };

canto.directive('annotationTable',
                ['CantoGlobals', 'AnnotationProxy',
                 'AnnotationTypeConfig', 'CursGenotypeList', 'CursSessionDetails', 'CantoConfig',
                 annotationTableCtrl]);


var annotationTableList =
  function(AnnotationProxy, AnnotationTypeConfig, CantoGlobals) {
    return {
      scope: {
        featureIdFilter: '@',
        featureTypeFilter: '@',
        featureFilterDisplayName: '@',
      },
      restrict: 'E',
      replace: true,
      templateUrl: app_static_path + 'ng_templates/annotation_table_list.html',
      controller: function($scope) {
        $scope.app_static_path = CantoGlobals.app_static_path;
        $scope.annotationTypes = [];
        $scope.annotationsByType = {};
        $scope.serverErrorsByType = {};

        $scope.data = {};

        AnnotationTypeConfig.getAll().then(function(response) {
          $scope.annotationTypes =
            $.grep(response.data,
                   function(annotationType) {
                     if ($scope.featureTypeFilter === undefined ||
                         $scope.featureTypeFilter === 'gene' ||
                         annotationType.feature_type === $scope.featureTypeFilter) {
                       return annotationType;
                     }
                   });

          $.map($scope.annotationTypes,
                function(annotationType) {
                  AnnotationProxy.getAnnotation(annotationType.name)
                    .then(function(annotations) {

                      var params = {
                        featureId: $scope.featureIdFilter,
                        featureType: $scope.featureTypeFilter,
                      };
                      $scope.annotationsByType[annotationType.name] =
                        filterAnnotations(annotations, params);
                    }).catch(function() {
                      $scope.serverErrorsByType[annotationType.name] =
                        "couldn't read annotations from the server - please contact the curators";
                    });
                });
        }).catch(function(data, status) {
          if (status) {
            $scope.data.serverError = "couldn't read annotation types from the server ";
          } // otherwise the request was cancelled
        });
      },
    };
  };

canto.directive('annotationTableList', ['AnnotationProxy', 'AnnotationTypeConfig', 'CantoGlobals', annotationTableList]);


var annotationTableRow =
  function($modal, AnnotationProxy, AnnotationTypeConfig, CantoGlobals, CantoConfig, toaster) {
    return {
      restrict: 'A',
      replace: true,
      templateUrl: function(elem,attrs) {
        return app_static_path + 'ng_templates/annotation_table_' +
          attrs.annotationTypeName + '_row.html';
      },
      controller: function($scope) {
        $scope.curs_root_uri = CantoGlobals.curs_root_uri;
        $scope.read_only_curs = CantoGlobals.read_only_curs;
        $scope.multiOrganismMode = false;

        var annotation = $scope.annotation;

        $scope.displayEvidence = annotation.evidence_code;

        if (typeof($scope.annotation.conditions) !== 'undefined') {
          $scope.annotation.conditionsString =
            conditionsToString($scope.annotation.conditions);
        }

        var qualifiersList = [];

        if (typeof($scope.annotation.qualifiers) !== 'undefined' && $scope.annotation.qualifiers !== null) {
          qualifiersList = $scope.annotation.qualifiers;
        }

        if ($scope.annotation.is_not) {
          qualifiersList.unshift('NOT');
        }

        $scope.annotation.qualifiersString = qualifiersList.join(', ');

        var annotationTypePromise =
            AnnotationTypeConfig.getByName(annotation.annotation_type);
        annotationTypePromise
          .then(function(annotationType) {
            $scope.annotationType = annotationType;
          });

        CantoConfig.get('instance_organism').success(function(results) {
          if (!results.taxonid) {
            $scope.multiOrganismMode = true;
          }
        });

        $scope.$watch('annotation.evidence_code',
                      function(newEvidenceCode) {
                        if (newEvidenceCode) {
                          CantoConfig.get('evidence_types').success(function(results) {
                            $scope.evidenceTypes = results;

                            annotationTypePromise.then(function() {
                              $scope.displayEvidence = results[newEvidenceCode].name;
                            });
                          });
                        } else {
                          $scope.displayEvidence = '';
                        }
                      });

        $scope.addLinks = function() {
          return true;
        };

        $scope.featureLink = function(featureType, featureId) {
          return $scope.curs_root_uri + '/feature/' +
            featureType + '/view/' +
            featureId + ($scope.read_only_curs ? '/ro' : '');
        };

        $scope.edit = function() {
          // FIXME: featureFilterDisplayName is from the parent scope
          var editPromise =
            startEditing($modal, annotation.annotation_type, $scope.annotation,
                         $scope.featureFilterDisplayName, false, true);

          editPromise.then(function(editedAnnotation) {
            $scope.annotation = editedAnnotation;
            if (typeof($scope.annotation.conditions) !== 'undefined') {
              $scope.annotation.conditionsString =
                conditionsToString($scope.annotation.conditions);
            }
          });
        };

        $scope.duplicate = function() {
          var newAnnotation = makeNewAnnotation($scope.annotation);
          startEditing($modal, annotation.annotation_type,
                       newAnnotation, $scope.featureFilterDisplayName,
                       true, true);
        };

        $scope.deleteAnnotation = function() {
          loadingStart();
          AnnotationProxy.deleteAnnotation(annotation)
            .then(function() {
              toaster.pop('success', 'Annotation deleted');
            })
            .catch(function(message) {
              toaster.pop('note', "Couldn't delete the annotation: " + message);
            })
            .finally(function() {
              loadingEnd();
            });
        };
      },
    };
  };

canto.directive('annotationTableRow',
                ['$modal', 'AnnotationProxy', 'AnnotationTypeConfig',
                 'CantoGlobals', 'CantoConfig', 'toaster',
                 annotationTableRow]);


var annotationSingleRow =
  function(AnnotationTypeConfig, CantoConfig, CantoService, Curs) {
    return {
      restrict: 'E',
      scope: {
        featureType: '@',
        featureDisplayName: '@',
        annotationTypeName: '@',
        annotationDetails: '=',
      },
      replace: true,
      templateUrl: function(elem,attrs) {
        return app_static_path + 'ng_templates/annotation_single_row.html';
      },
      controller: function($scope) {
        $scope.displayFeatureType = capitalizeFirstLetter($scope.featureType);

        $scope.displayEvidence = '';
        $scope.conditionsString = '';
        $scope.withGeneDisplayName = '';

        AnnotationTypeConfig.getByName($scope.annotationTypeName)
          .then(function(annotationType) {
            $scope.annotationType = annotationType;
          });

        $scope.$watch('annotationDetails.term_ontid',
                      function(newId) {
                        if (newId) {
                          CantoService.lookup('ontology', [newId],
                                              {
                                                def: 1,
                                                children: 1,
                                                exact_synonyms: 1,
                                                subset_ids: 1,
                                              })
                            .then(function(response) {
                              $scope.termDetails = response.data;
                            });
                        } else {
                          $scope.termDetails = {};
                        }
                      });

        $scope.$watch('annotationDetails.conditions',
                      function(newConditions) {
                        if (newConditions) {
                          $scope.conditionsString =
                            conditionsToString(newConditions);
                        }
                      },
                      true);

        $scope.$watch('annotationDetails.evidence_code',
                      function(newCode) {
                        $scope.displayEvidence = newCode;

                        if (newCode) {
                          CantoConfig.get('evidence_types').success(function(results) {
                            $scope.evidenceTypes = results;
                            $scope.displayEvidence = results[newCode].name;
                          });
                        }
                      });

        $scope.$watch('annotationDetails.with_gene_id',
                      function(newWithId) {
                        if (newWithId) {
                          Curs.list('gene').success(function(results) {
                            $scope.genes = results;

                            $.map($scope.genes,
                                  function(gene) {
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
                 annotationSingleRow]);


var termNameComplete =
  function($timeout) {
    return {
      scope: {
        annotationTypeName: '@',
        currentTermName: '@',
        foundCallback: '&',
      },
      controller: function($scope) {
        $scope.render_term_item =
          function(ul, item, search_string) {
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
            if (searchAnnotationTypeName !== item.annotation_type_name) {
              warning = '<br/><span class="autocomplete-warning">WARNING: this is the ID of a ' +
                item.annotation_type_name + ' term but<br/>you are browsing ' +
                searchAnnotationTypeName + ' terms</span>';
              var re = new RegExp('_', 'g');
              // unpleasant hack to make the namespaces look nicer
              warning = warning.replace(re,' ');
            }
            function length_compare(a,b) {
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
                var re = new RegExp('(\\b' + bit + ')', "gi");
                match_name = match_name.replace(re,'<b>$1</b>');
              }
            }
            return $( "<li></li>" )
              .data( "item.autocomplete", item )
              .append( "<a>" + match_name + " <span class='term-id'>(" +
                       item.id + ")</span>" + synonym_extra + warning + "</a>" )
              .appendTo( ul );
          };
      },
      replace: true,
      restrict: 'E',
      template: '<input size="40" type="text" class="form-control" autofocus value="{{currentTermName}}"/>',
      link: function(scope, elem) {
        var valBeforeComplete = null;
        elem.autocomplete({
          minLength: 2,
          source: make_ontology_complete_url(scope.annotationTypeName),
          cacheLength: 100,
          focus: ferret_choose.show_autocomplete_def,
          open: function(ev) {
            valBeforeComplete = elem.val();
          },
          close: ferret_choose.hide_autocomplete_def,
          select: function(event, ui) {
            var trimmedValBeforeComplete = null;
            if (valBeforeComplete) {
              trimmedValBeforeComplete = trim(valBeforeComplete);
            }
            $timeout(function() {
              scope.foundCallback({ termId: ui.item.id,
                                    termName: ui.item.value,
                                    searchString: trimmedValBeforeComplete,
                                    matchingSynonym: ui.item.matching_synonym,
                                  });
            }, 1);
            valBeforeComplete = null;
          },
        }).data("autocomplete")._renderItem = function( ul, item ) {
          var search_string = elem.val();
          return scope.render_term_item(ul, item, search_string);
        };
        elem.attr('disabled', false);

        function do_autocomplete (){
          elem.focus();
          scope.$apply(function() {
            elem.autocomplete('search');
          });
        }

        elem.bind('paste', function() {
          setTimeout(do_autocomplete, 10);
        });

        elem.bind('click', function() {
          setTimeout(do_autocomplete, 10);
        });

        elem.keypress(function(event) {
          if (event.which == 13) {
            // return should autocomplete not submit the form
            event.preventDefault();
            do_autocomplete();
          }
        });
      }
    };
  };

canto.directive('termNameComplete', ['$timeout', termNameComplete]);


var termChildrenQuery =
  function($modal, CantoService) {
    return {
      scope: {
        termId: '=',
        termName: '=',
      },
      controller: function($scope) {
        $scope.data = { children: [] };

        $scope.confirmTerm = function() {
          var termConfirm = openTermConfirmDialog($modal, $scope.termId, 'children');

          termConfirm.result.then(function(result) {
            $scope.termId = result.newTermId;
            $scope.termName = result.newTermName;
          });
        };
      },
      replace: true,
      restrict: 'E',
      templateUrl: app_static_path + 'ng_templates/term_children_query.html',
      link: function($scope) {
        $scope.$watch('termId',
                      function(newTermId) {
                        if (newTermId) {
                          var promise = CantoService.lookup('ontology', [$scope.termId],
                                                            {
                                                              def: 1,
                                                              children: 1,
                                                              exact_synonyms: 1,
                                                            });

                          promise.success(function(data) {
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

canto.directive('termChildrenQuery', ['$modal', 'CantoService', termChildrenQuery]);


var initiallyHiddenText =
  function() {
    return {
      scope: {
        text: '@',
        linkLabel: '@',
      },
      restrict: 'E',
      replace: true,
      link: function($scope, elem) {
        var $view = $(elem).find('a');
        var $element = $(elem).find('span');
        $view.on('click',
                 function () {
                   $view.hide();
                   $element.show();
                 });

        $scope.$watch('text',
                      function() {
                        if ($.trim($scope.text).length > 0) {
                          $element.hide();
                          $view.show();
                        } else {
                          $view.hide();
                        }
                      });
      },
      template: '<span><span title="{{text}}">{{text}}</span><a class="ng-cloak" title="{{text}}" tooltip="{{text}}" >{{linkLabel}}</a></span>',
    };
  };

canto.directive('initiallyHiddenText', [initiallyHiddenText]);

