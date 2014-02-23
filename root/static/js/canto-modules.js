var canto = angular.module('cantoApp', ['ui.bootstrap']);

var alleleEditDialogCtrl =
  function($scope, $http, $modalInstance, $q, $timeout, CantoConfig, gene_display_name, gene_systemtic_id, gene_id) {
    $scope.gene = {
      display_name: gene_display_name,
      systemtic_id: gene_systemtic_id,
      gene_id: gene_id
    };
    $scope.alleleData = {
      name: '',
      description: '',
      type: '',
      expression: '',
      evidence: '',
      conditions: []
    };

    $scope.loadConditions = function() {
      var deferred = $q.defer();

      deferred.resolve(['foo', 'bar']);

      return deferred.promise;
    };

    $scope.env = {
      used_conditions: {}
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
      if (typeof this.current_type_config == 'undefined') {
        return ''
      }
      var autopopulate_name = this.current_type_config.autopopulate_name;
      if (typeof autopopulate_name == 'undefined') {
        return '';
      } else {
        $scope.alleleData.name =
          autopopulate_name.replace(/@@gene_name@@/, this.gene.display_name);
        return this.alleleData.name;
      }
    }

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
      return !$scope.current_type_config || !$scope.current_type_config.allele_name_required || $scope.alleleData.name;
    };

    $scope.isValidDescription = function() {
      return !$scope.current_type_config || !$scope.current_type_config.description_required || $scope.alleleData.description;
    };

    $scope.isValid = function() {
      return $scope.isValidType() &&
        $scope.isValidName() && $scope.isValidDescription();
      // evidence and expression ...
    };

    // if (data ...) {
    //   populate_dialog_from_data(...);
    // }

    // current_conditions comes from the .mhtml file
    if (typeof(current_conditions) != 'undefined') {
      $scope.env.used_conditions = current_conditions;
    }

    function allele_lookup(request, response) {
      $.ajax({
        url: ferret_choose.allele_lookup_url,
        data: { gene_primary_identifier: genePrimaryIdentifier,
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

    //  $('#curs-allele-add .curs-allele-name').autocomplete({
    //    source: allele_lookup,
    //    select: function(event, ui) {
    //      var $description = get_allele_desc_jq($allele_dialog).val(ui.item.description);
    //      if (typeof(ui.item.allele_type) === 'undefined' ||
    //          ui.item.allele_type === 'unknown') {
    //        $scope.type = undefined;
    //      } else {
    //        $scope.type = ui.item.allele_type;
    //      }
    //    }
    //  }).data("autocomplete" )._renderItem = function(ul, item) {
    //    return $( "<li></li>" )
    //      .data( "item.autocomplete", item )
    //      .append( "<a>" + item.display_name + "</a>" )
    //      .appendTo( ul );
    //  };

    //  make_condition_buttons($allele_dialog);

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
        conditions: $scope.alleleData.conditions,
        gene_id: $scope.gene.gene_id
      };
    }

    function fetch_conditions(search, showChoices) {
      $.ajax({
        url: make_ontology_complete_url('phenotype_condition'),
        data: { term: search.term, def: 1, },
        dataType: "json",
        success: function(data) {
          var choices = $.map( data, function( item ) {
            var label;
            if (item.matching_synonym == null) {
              label = item.name;
            } else {
              label = item.matching_synonym + ' (synonym)';
            }
            return {
              label: label,
              value: item.name,
              name: item.name,
              definition: item.definition,
            }
          });
          showChoices(choices);
        },
      });
    }

    $timeout(function() {
      var updateScopeConditions = function() {
        var conditions = $('.curs-allele-conditions').val();

        $scope.alleleData.conditions = conditions.split(',');
      };

      // this is a hack and there will be a better way -
      // .curs-allele-conditions isn't available until after the
      // constructor finishes
      $('.curs-allele-conditions').tagit({
        minLength: 2,
        fieldName: 'curs-allele-condition-names',
        allowSpaces: true,
        placeholderText: 'Type a condition ...',
        tagSource: fetch_conditions,
        afterTagAdded: updateScopeConditions,
        afterTagRemoved: updateScopeConditions,
        autocomplete: {
          focus: ferret_choose.show_autocomplete_def,
          close: ferret_choose.hide_autocomplete_def,
        },
      });
    }, 0);

    function make_condition_buttons($allele_dialog, $allele_table) {
      return;

      $allele_table.find('tr').map(function(idx, el) {
        var el_allele_data = $(el).data('allele_data');
        if (typeof(el_allele_data) != 'undefined') {
          $.map(el_allele_data.conditions,
                function(cond, idx) {
                  $scope.env.used_conditions[cond] = true;
                });
        }
      });
      var button_html = '';

      var used_buttons = $allele_dialog.find('.curs-allele-condition-buttons');

      used_buttons.find('button').remove();

      $.each($scope.env.used_conditions,
             function(cond) {
               button_html += '<button class="ui-widget ui-state-default curs-allele-condition-button">' +
                 '<span>' + cond + '</span></button>';
             });

      if (button_html === '') {
        used_buttons.hide();
      } else {
        used_buttons.show();
        used_buttons.append(button_html);

        $('.curs-allele-condition-buttons button').click(function() {
          get_allele_conditions_jq($allele_dialog).tagit("createTag", $(this).find('span').text());
          return false;
        }).button({
          icons: {
            secondary: "ui-icon-plus"
          }
        });
      }
    }

    $scope.ok = function () {
      $modalInstance.close($scope.dialogToData($scope));
    };

    $scope.cancel = function () {
      $modalInstance.dismiss('cancel');
    };
  };

canto.controller('AlleleEditDialogCtrl',
                 ['$scope', '$http', '$modalInstance', '$q', '$timeout',
                  'CantoConfig', 'gene_display_name', 'gene_systemtic_id', 'gene_id',
                 alleleEditDialogCtrl]);

canto.controller('MultiAlleleCtrl', ['$scope', '$http', '$modal', '$location', function($scope, $http, $modal, $location) {
  $scope.alleles = [
  ];

  $scope.storeAlleles = function() {
    $http.post('store', $scope.alleles).
      success(function(data) {
        window.location.href = data.location;
        console.debug(data);
      }).
      error(function(data){
        console.debug("failed test");
      });
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
          gene_display_name: function() { return gene_display_name; },
          gene_systemtic_id: function () { return gene_systemtic_id; },
          gene_id: function () { return gene_id; }
        }
      });

      editInstance.result.then(function (alleleData) {
        $scope.alleles.push(alleleData);
      }, function () {
        // cancelled
      });
    };

  $scope.openAlleleEditDialog('cdc11', 'SPAC111c.22', 1);

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

$(document).ready(function() {
  $('.curs-js-link').show();
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
      $scope.data.noAnnotation &&
      $scope.data.noAnnotationReason.length > 0 &&
      ($scope.data.noAnnotationReason !== "Other" ||
       $scope.data.otherText.length > 0);
  }
}

canto.factory('CantoConfig', function($http) {
  return {
    get : function(key){
      return $http.get(canto_root_uri + 'ws/canto_config/' + key);
    }
  }
});
