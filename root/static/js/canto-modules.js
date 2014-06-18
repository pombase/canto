'use strict';

/*global curs_root_uri,angular,$,make_ontology_complete_url,ferret_choose,application_root */

var canto = angular.module('cantoApp', ['ui.bootstrap', 'xeditable']);

canto.config(function($logProvider){
    $logProvider.debugEnabled(true);
});

canto.factory('Curs', function($http) {
  return {
    list : function(key) {
      return $http.get(curs_root_uri + '/ws/' + key + '/list');
    }
  };
});

canto.run(function(editableOptions) {
  editableOptions.theme = 'bs3';
});

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

var conditionPicker =
  function() {
    var directive = {
      scope: {
      },
      restrict: 'E',
      replace: true,
      templateUrl: 'condition_picker.html',
      link: function(scope, elem) {
        var button_html = '';
        var used_buttons = elem.find('.curs-allele-condition-buttons');

        elem.find('.curs-allele-conditions').tagit({
          minLength: 2,
          fieldName: 'curs-allele-condition-names',
          allowSpaces: true,
          placeholderText: 'Type a condition ...',
          tagSource: fetch_conditions,
          //          afterTagAdded: updateScopeConditions,
          //          afterTagRemoved: updateScopeConditions,
          autocomplete: {
            focus: ferret_choose.show_autocomplete_def,
            close: ferret_choose.hide_autocomplete_def,
          },
        });

        used_buttons.find('button').remove();

//        $.each(scope.data.used_conditions,
//               function(cond) {
//                 button_html += '<button class="ui-widget ui-state-default curs-allele-condition-button">' +
//                   '<span>' + cond + '</span></button>';
//               });

        if (button_html === '') {
          used_buttons.hide();
        } else {
          used_buttons.show();
          used_buttons.append(button_html);

          $('.curs-allele-condition-buttons button').click(function() {
            elem.find('curs-allele-conditions').tagit("createTag", $(this).find('span').text());
            return false;
          }).button({
            icons: {
              secondary: "ui-icon-plus"
            }
          });
        }
      }
    };

    return directive;
  };

canto.directive('conditionPicker', conditionPicker);

var alleleEditDialogCtrl =
  function($scope, $http, $modalInstance, $q, $timeout, CantoConfig, args) {
    $scope.gene = {
      display_name: args.gene_display_name,
      systemtic_id: args.gene_systemtic_id,
      gene_id: args.gene_id
    };
    $scope.alleleData = {
      name: '',
      description: '',
      type: '',
      expression: '',
      evidence: ''
    };
    $scope.current_type_config = undefined;

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
      if (autopopulate_name === undefined) {
        return '';
      }

      $scope.alleleData.name =
        autopopulate_name.replace(/@@gene_name@@/, this.gene.display_name);
      return this.alleleData.name;
    };

    $scope.typeChange = function(curType) {
      $scope.env.allele_types_promise.then(function(response) {
        $scope.current_type_config = response.data[curType];

        if ($scope.name_autopopulated) {
          if ($scope.name_autopopulated == $scope.alleleData.name) {
            $scope.alleleData.name = '';
          }
          $scope.name_autopopulated = '';
        }

        $scope.name_autopopulated = $scope.maybe_autopopulate();
        $scope.alleleData.description = '';
      });
    };

    $scope.isValidType = function() {
      return !!$scope.alleleData.type;
    };

    $scope.isValidName = function() {
      return !$scope.current_type_config || $scope.current_type_config.allele_name_required == 0 || $scope.alleleData.name;
    };

    $scope.isValidDescription = function() {
      return !$scope.current_type_config || $scope.current_type_config.description_required == 0 || $scope.alleleData.description;
    };

    $scope.isValid = function() {
      return $scope.isValidType() &&
        $scope.isValidName() && $scope.isValidDescription();
      // evidence and expression if needed ...
    };

    // if (data ...) {
    //   populate_dialog_from_data(...);
    // }

    function allele_lookup(request, response) {
      $.ajax({
        url: application_root + 'ws/lookup/allele',
        data: { gene_primary_identifier: $scope.gene.systemtic_id,
                ignore_case: true,
                term: request.term },
        dataType: 'json',
        success: function(data) {
          var results =
            $.grep(
              existing_alleles_by_name,
              function(el) {
                return typeof(el.value) !== 'undefined' && el.value.indexOf(request.term) == 0;
              })
            .concat($.map(
              data,
              function(el) {
                return {
                  value: el.name,
                  display_name: el.display_name,
                  description: el.description,
                  allele_type: el.allele_type
                }
              }));
          response(results);
        },
        async: true
      });
    }

    $timeout(function() {
      // this is a hack - curs-allele-name isn't in the DOM until after this
      // executes
      $('input.curs-allele-name').autocomplete({
        source: allele_lookup,
        select: function(event, ui) {
          if (typeof(ui.item.allele_type) === 'undefined' ||
              ui.item.allele_type === 'unknown') {
            $scope.type = undefined;
          } else {
            $scope.type = ui.item.allele_type;
          }
        }
      }).data("autocomplete" )._renderItem = function(ul, item) {
        return $( "<li></li>" )
          .data( "item.autocomplete", item )
          .append( "<a>" + item.display_name + "</a>" )
          .appendTo( ul );
      };
    });

    //  var name_input = $allele_dialog.find('.curs-allele-name');
    //  name_input.attr('placeholder', 'Allele name (optional)');

    // return the data from the dialog as an Object
    $scope.dialogToData = function($scope) {
      return {
        name: $scope.alleleData.name,
        description: $scope.alleleData.description,
        type: $scope.alleleData.type,
        evidence: $scope.alleleData.evidence,
        expression: $scope.alleleData.expression,
        gene_id: $scope.gene.gene_id
      };
    };

    $scope.ok = function () {
      $modalInstance.close($scope.dialogToData($scope));
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('AlleleEditDialogCtrl',
                 ['$scope', '$http', '$modalInstance', '$q', '$timeout',
                  'CantoConfig', 'args',
                 alleleEditDialogCtrl]);

canto.controller('MultiAlleleCtrl', ['$scope', '$http', '$modal', '$location', 'CantoConfig', 'Curs', function($scope, $http, $modal, $location, CantoConfig, Curs) {
  $scope.alleles = [
  ];
  $scope.genes = [
  ];
  $scope.selectedGenes = [
  ];

  Curs.list('gene').success(function(results) {
    $scope.genes = results;
  })
  .error(function() {
    alert('failed to get gene list from server');
  });

  $scope.currentlySelectedGenes = function() {
    return $.grep($scope.genes, function(value, index) {
      return value.selected;
    });
  };

  $scope.selectGenes = function() {
    $scope.selectedGenes = $scope.currentlySelectedGenes();
  };

  $scope.clearSelectedGene = function() {
    $scope.selectedGenes = [];
  };

  $scope.data = {
    genotype_identifier: '',
    genotype_name: ''
  };

  $scope.env = {
    curs_config_promise: CantoConfig.get('curs_config')
  };

  $scope.$watch('alleles',
                function() {
                  $scope.env.curs_config_promise.then(function(response) {
                    $scope.data.genotype_identifier =
                      response.data.genotype_config.default_strain_name +
                      " " +
                      $.map($scope.alleles, function(val, i) {
                        if (val.description === '') {
                          return val.name + "(" + val.type + ")";
                        } else {
                          return val.name + "(" + val.description + ")";
                        }
                      }).join(" ");
                  });
                },
                true);

  $scope.storeAlleles = function() {
    $http.post('store', { genotype_name: $scope.data.genotype_name,
                          genotype_identifier: $scope.data.genotype_identifier,
                          alleles: $scope.alleles }).
      success(function(data) {
        window.location.href = data.location;
        console.debug(data);
      }).
      error(function(data){
        console.debug("failed test");
      });
  };

  $scope.removeAllele = function (allele) {
    $scope.alleles.splice($scope.alleles.indexOf(allele), 1);
  };

  $scope.openAlleleEditDialog =
    function(gene_display_name, gene_systemtic_id, gene_id) {
      var editInstance = $modal.open({
        templateUrl: 'alleleEdit.html',
        controller: 'AlleleEditDialogCtrl',
        title: 'Add an allele for this phenotype',
        animate: false,
        windowClass: "modal",
        resolve: {
          args: function() {
            return {
              gene_display_name: gene_display_name,
              gene_systemtic_id: gene_systemtic_id,
              gene_id: gene_id
            }
          }
        }
      });

      editInstance.result.then(function (alleleData) {
        $scope.alleles.push(alleleData);
      }, function () {
        // cancelled
      });
    };

  $scope.isValid = function() {
    return $scope.alleles.length > 0;
  }
}]);


var EditDialog = function($) {
  function confirm($dialog) {
    var $form = $('#curs-edit-dialog form');
    $dialog.dialog('close');
    $('#loading').unbind('ajaxStop.canto');
    $form.ajaxSubmit({
          dataType: 'json',
          success: function(data) {
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
      $dialog_div.remove()
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

var QuickAddDialog = function($) {
  function confirm($dialog) {
    var $form = $('#curs-quick-add-dialog form');
    if ($form.validate().form()) {
      $('#loading').unbind('ajaxStop.canto');
      $form.ajaxSubmit({
        dataType: 'json',
        success: function(data) {
          $dialog.dialog("destroy");
          var $dialog_div = $('#curs-quick-add-dialog');
          $dialog_div.remove();
          window.location.reload(false);
        }
      });
    }
  }

  function cancel() {
    $(this).dialog("destroy");
    var $dialog_div = $('#curs-quick-add-dialog');
    $dialog_div.remove();
  }

  function create(title, search_namespace, form_url) {
    var $dialog_div = $('#curs-quick-add-dialog');
    if ($dialog_div.length) {
      $dialog_div.remove()
    }

    var evidence_select_html = '<select id="ferret-quick-add-evidence" name="ferret-quick-add-evidence"><option selected="selected" value="">Choose an evidence type ...</option>'
    $.map(evidence_by_annotation_type[search_namespace],
          function(item) {
            evidence_select_html += '<option value="' + item + '">' + item + '</option>';
          });
    evidence_select_html += '</select>';

    var with_gene_html =
      '<select id="ferret-quick-add-with-gene" name="ferret-quick-add-with-gene">' +
      '<option selected="selected" value="">With gene ...</option>';
    $.map(genes_in_session,
          function(gene) {
            with_gene_html += '<option value="' + gene.id + '">' + gene.display_name + '</option>';
          });
    with_gene_html += '</select>';

    var dialog_html =
      '<div id="curs-quick-add-dialog" style="display: none">' +
      '<form action="' + form_url + '" method="post">' +
      '<input type="hidden" id="ferret-quick-add-term-id" name="ferret-quick-add-term-id"/>' +
      '<input id="ferret-quick-add-term-input" name="ferret-quick-add-term-entry" type="text"' +
      '       size="50" disabled="true" ' +
      '       placeholder="start typing and suggestions will be made ..." />' +
      '<br/>' +
      evidence_select_html +
      '<br/>' +
      '<div id="ferret-quick-add-with-gene-wrapper" style="display:none">' +
      with_gene_html +
      '</div>' +
      '<input id="ferret-quick-extension" name="ferret-quick-add-extension" type="text"' +
      '       size="50" ' +
      '       placeholder="Optional annotation extension ..." />' +
      '</form></div>';

    $dialog_div = $(dialog_html);

    var select_callback = function(event, ui) {
      $('#ferret-quick-add-term-id').val(ui.item.id);
    };

    var $form = $dialog_div.find('form');
    $form.validate({
      rules: {
        'ferret-quick-add-term-entry': {
          required: true,
        },
        'ferret-quick-add-evidence': {
          required: true,
        },
        'ferret-quick-add-with-gene': {
          required: function() {
           return $('#ferret-quick-add-with-gene').is(':visible');
          }
        }
      }
    });

    var $dialog = $dialog_div.dialog({
      modal: true,
      autoOpen: true,
      height: 'auto',
      width: 600,
      title: title,
      open: function() {
        var ferret_input = $('#ferret-quick-add-term-input');
        ferret_input.autocomplete({
          minLength: 2,
          source: make_ontology_complete_url(search_namespace),
          select: select_callback,
          cacheLength: 100,
        });
        ferret_input.attr('disabled', false);
      },
      buttons : [
                 {
                   text: "Cancel",
                   click: cancel,
                 },
                 {
                   text: "Add",
                   click: function() {
                     confirm($dialog);
                   },
                 },
               ],
    });

    var $with_gene_wrapper = $('#ferret-quick-add-with-gene-wrapper');

    $('#ferret-quick-add-evidence').on('change',
                                       function(event) {
                                         var evidence = $(this).val();
                                         if (evidence in with_gene_evidence_codes) {
                                           $with_gene_wrapper.show();
                                         } else {
                                           $with_gene_wrapper.hide();
                                         }
                                       })

    return $dialog;
  }

  return {
    create: create
  };
}($);

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
      $scope.data.noAnnotation &&
      $scope.data.noAnnotationReason.length > 0 &&
      ($scope.data.noAnnotationReason !== "Other" ||
       $scope.data.otherText.length > 0);
  }
}

function SubmitToCuratorsCtrl($scope) {
  $scope.data = {
    reason: null,
    hasAnnotation: false
  };
  $scope.noAnnotationReasons = ['Review'];

  $scope.init = function(reasons) {
    $scope.noAnnotationReasons = reasons;
  };

  $scope.validReason = function() {
    return $scope.data.reason != null && $scope.data.reason.length > 0;
  };
}

canto.factory('CantoConfig', function($http) {
  return {
    get : function(key){
      return $http.get(canto_root_uri + 'ws/canto_config/' + key);
    }
  }
});

// to be implemented
var ferretCtrl = function($scope) {

};

// add ng-controller="FerretCtrl" to <div id="ferret"> in ontology.mhtml

canto.controller('FerretCtrl', ['$scope', 'CantoConfig', ferretCtrl]);

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
      $scope.data.noAnnotation &&
      $scope.data.noAnnotationReason.length > 0 &&
      ($scope.data.noAnnotationReason !== "Other" ||
       $scope.data.otherText.length > 0);
  }
}

function AlleleCtrl($scope) {
  $scope.alleles = [
  {name: 'name1', description: 'desc', type: 'type1'}
  ];
}

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


var evidenceSelectCtrl =
  function ($scope) {
    $scope.data = {};
  };

canto.controller('EvidenceSelectCtrl',
                 ['$scope', evidenceSelectCtrl]);
