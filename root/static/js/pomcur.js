function last(a) {
  return a[a.length-1];
}

function trim(a) {
  a=a.replace(/^\s+/,''); return a.replace(/\s+$/,'');
};

$(document).ready(function() {
  $(".sect .undisclosed-title, .sect .disclosed-title").each(function(i) {
    $(this).click(function() {
      $(this).next().toggle();
      $(this).toggleClass('undisclosed-title');
      $(this).toggleClass('disclosed-title');
      return false;
    });
    if ($(this).is(".undisclosed-title")) {
      $(this).next().hide();
    } else {
      $(this).next().show();
    }
  });
});

function make_ontology_complete_url(annotation_type) {
  return application_root + 'ws/lookup/ontology/' + annotation_type;
}

var ferret_choose = {
  // element 0 is the orginal text we searched for, last element is the current
  // selected term, the other elements are the history/trail
  term_history : [undefined],
  term_detail_cache : {},
  annotation_namespace: undefined,

  // the synonym we match when searching, if any
  matching_synonym : undefined,

  initialise : function(annotation_type, annotation_namespace) {
    ferret_choose.ontology_complete_url = make_ontology_complete_url(annotation_type);
    ferret_choose.annotation_type = annotation_type;
    ferret_choose.annotation_namespace = annotation_namespace;
  },

  debug : function(message) {
//    $("#ferret").append("<div>" + message + "</div>");
  },

  store_term_data : function(data) {
    var term = data[0];
    ferret_choose.debug("adding to cache: " + term.id + " " + term.name);
    ferret_choose.term_detail_cache[term.id] = term;
  },

  fetch_term_detail : function(term_id) {
    ferret_choose.debug("fetching: " + term_id);
    $.ajax({
      url: ferret_choose.ontology_complete_url,
      data: { term: term_id, def: 1, children: 1 },
      dataType: 'json',
      success: ferret_choose.store_term_data,
      async: false
    });
    $('#ferret-term-entry').hide();
  },

  get_term_by_id : function(term_id) {
    if (!ferret_choose.term_detail_cache[term_id]) {
      ferret_choose.fetch_term_detail(term_id);
    }

    ferret_choose.debug("looking for in cache: " + term_id);
    ferret_choose.debug("returning from cache: " + ferret_choose.term_detail_cache[term_id]);
    var term = ferret_choose.term_detail_cache[term_id];

    return term;
  },

  get_current_term : function() {
    return last(ferret_choose.term_history);
  },

  set_current_term : function(term_id) {
    $('#ferret-term-id').val(term_id);

    ferret_choose.debug("set_current_term: " + term_id);

    if (term_id) {
      if (term_id == 'search') {
        ferret_choose.term_history.length = 1;
      } else {
        var i;
        for (i = 1; i < ferret_choose.term_history.length; i++) {
          var value = ferret_choose.term_history[i];
          if (term_id == value) {
            // truncate the array, making term_id the last element
            ferret_choose.term_history.length = i + 1;
            break;
          }
        }

        if (i == ferret_choose.term_history.length) {
          ferret_choose.term_history.push(term_id);
        }
      }
    }

    var bbq_state = {
      "s" : ferret_choose.term_history[0],
      "c" : ferret_choose.term_history.slice(1).join(",")
    };

    $.bbq.pushState(bbq_state);
  },

  add_to_breadcrumbs : function(term, make_link) {
    var dest = $('#breadcrumbs-search');
    // find the most nested div
    while (true) {
      var children = dest.children('div');
      if (children.length > 0) {
        dest = children.first();
      } else {
        break;
      }
    }
    var link_start;
    var link_end;

    if (make_link) {
      link_start = '<a title="' + term.name + '" href="#' + term.id + '">';
      link_end = '</a>';
    } else {
      link_start = '';
      link_end = '';
    }
    var div = $('<div class="breadcrumbs-link breadcrumbs-ferret-term">' +
                link_start + term.name + link_end + '</div>');
    div.data('term', term);
    dest.append(div);
  },

  render_breadcrumbs : function(term_id) {
    $('#breadcrumbs-search').remove();
    var history_length = ferret_choose.term_history.length;
    var search_string = ferret_choose.term_history[0];

    if (!search_string) {
      search_string = '';
    }

    var link_start;
    var link_end;
    if (history_length > 1) {
      link_start = '<a href="#search">';
      link_end = '</a>';
    } else {
      link_start = '';
      link_end = '';
    }
    var search_text;
    if (search_string.length == 0) {
      search_text = "Search";
    } else {
      search_text = 'Search: "' + search_string + '"';
    }
    var html = '<div class="breadcrumbs-link" id="breadcrumbs-search">' +
      link_start + search_text + link_end +
      '</div>';
    $('#breadcrumbs-gene-link').append(html);

    if (ferret_choose.term_history.length > 1) {
      for (var i = 1; i < history_length; i++) {
        var term_id = ferret_choose.term_history[i];
        var term = ferret_choose.get_term_by_id(term_id);
        var make_link = (i != history_length - 1);
        ferret_choose.add_to_breadcrumbs(term, make_link);
      }
    };
  },

  // if link has no fragment, go to search page
  move_to_hash_term : function(link) {
    var href = link.attr('href');
    var index = href.indexOf('#');
    if (index < 0) {
      ferret_choose.set_current_term();
    } else {
      var term_id = href.substring(index + 1);
      ferret_choose.set_current_term(term_id);
    }
  },

  term_click_handler : function(event) {
    ferret_choose.move_to_hash_term($(event.target));
    return false;
  },

  child_click_handler : function(event) {
    ferret_choose.move_to_hash_term($(event.target).closest('a'));
    return false;
  },

  show_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.show();
    ferret_choose.hide_leaf();
  },

  hide_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.hide();
  },

  show_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.show();
    ferret_choose.hide_children();
  },

  hide_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.hide();
  },

  suggest_dialog : function() {
    $('#ferret-suggest-term-id').val($('#ferret-term-id').val());
    var term_name = $('.ferret-term-name').first().text();
    $('#ferret-suggest').dialog({ modal: true,
                                  title:
                                  'Suggest a new child term of "' +
                                   term_name + '"',
                                  width: 800 });
    return false;
  },

  render : function() {
    if (ferret_choose.term_history.length <= 1) {
      $('#ferret-term-details').hide();
      $('#ferret-term-entry').show();

      var term_input = $('#ferret-term-input');
      term_input.focus();
      term_input.autocomplete('search');
    } else {
      $('#ferret-term-details').show();
      $('#ferret-term-entry').hide();

      var term_id = last(ferret_choose.term_history);
      var term = ferret_choose.get_term_by_id(term_id);

      $('.ferret-term-name').text(term.name);
      $('#ferret-term-definition').text(term.definition);
      $('.ferret-term-id-display').text(term_id);

      if (term.comment) {
        $('#ferret-term-comment-row').show();
        $('#ferret-term-comment').html('<div class="term-comment">' +
                                       term.comment + '</div>');
      } else {
        $('#ferret-term-comment-row').hide();
        $('#ferret-term-comment').html('');
      }

      if (ferret_choose.matching_synonym && ferret_choose.term_history.length == 2) {
        $('#ferret-term-synonym-row').show();
        $('#ferret-term-synonym').html('<div class="term-synonym">' +
                                       ferret_choose.matching_synonym + '</div>');
      } else {
        $('#ferret-term-synonym-row').hide();
        $('#ferret-term-synonym').html('');
      }

      ferret_choose.debug("render(): " + term_id + " " + term.name);

      var children = term.children;
      var children_html = '';

      $.each(children, function(idx, child) {
        var img_html =
          '<img src="' + application_root + 'static/images/right_arrow.png"/>';
        children_html += '<li><a href="#' + child.id + '">' +
          child.name + img_html + '</li></a>';
      });

      $('#ferret-term-children').data('child-count', children.length);
      $('#ferret-term-children-list').html($('<ul/>').append($(children_html)));

      if (children.length == 0) {
        ferret_choose.show_leaf();
      } else {
        ferret_choose.show_children();
      }

      var link_confs = ontology_external_links[ferret_choose.annotation_namespace];
      if (link_confs) {
        var html = '';
        $.each(link_confs, function(idx, link_conf) {
          var url = link_conf['url'];
          var re = /(@@term_ont_id@@)/;
          url = url.replace(re, term_id);
          var img_src =
            application_root + 'static/images/logos/' +
            link_conf['icon'];
          var title = 'View in: ' + link_conf['name'];
          html += '<div class="curs-external-link"><a target="_blank" href="' +
            url + '" title="' + title + '">';
          if (img_src) {
            html += '<img alt="' + title + '" src="' + img_src + '"/></a>'
          } else {
            html += title;
          }
          var link_img_src = application_root + 'static/images/ext_link.png';
          html += '<img src="' + link_img_src + '"/></div>';
        });
        $('#ferret-linkouts .links-container').html(html);
      }
    }

    ferret_choose.render_breadcrumbs();
  },

  ferret_reset : function() {
    // from: http://stackoverflow.com/questions/680241/blank-out-a-form-with-jquery
    $(':input','#ferret-form')
      .not(':button, :submit, :reset, :hidden')
      .val('')
      .removeAttr('checked')
      .removeAttr('selected');
    ferret_choose.term_history = [ferret_choose.term_history.first()];
    return true;
  }
};


var curs_home = {
  show_term_suggestion : function(term_ontid, name, definition) {
    var dialog_div = $('#curs-dialog');
    var html = '<div> Term name:' +
      '<span class="term-name">' + name + '</span></div>' +
      'Definition: <div class="term-definition">' + definition +
      '</div></div>';
    $('#curs-dialog').html(html);
    $('#curs-dialog').dialog({ modal: true,
                               title: 'Child term suggestion for ' + term_ontid});
  }
};

var pomcur_util = {
  show_message : function(title, message) {
    var dialog_div = $('#curs-dialog');
    var html = '<div>' + message + '</div>';
    $('#curs-dialog').html(html);
    $('#curs-dialog').dialog({ modal: true,
                               title: title});
  }
};

$(document).ready(function() {
  var ferret_input = $("#ferret-term-input");

  if (ferret_input.size()) {
    function render_term_item(ul, item, search_string, search_namespace) {
      var search_bits = search_string.split(/\W+/);
      var match_name = item.matching_synonym;
      var synonym_extra = '';
      if (match_name) {
        synonym_extra = ' (synonym)';
      } else {
        match_name = item.name;
      }
      var warning = '';
      if (search_namespace !== item.annotation_namespace) {
        warning = '<br/><span class="autocomplete-warning">WARNING: this is the ID of a ' +
          item.annotation_namespace + ' term but<br/>you are browsing ' +
          search_namespace + ' terms</span>';
        var re = new RegExp('_', 'g');
        // unpleasant hack to make the namespaces look nicer
        warning = warning.replace(re,' ');
      }
      function length_compare(a,b) {
        if (a.length < b.length) {
          return 1;
        } else {
          if (a.length > b.length) {
            return -1;
          } else {
            return 0;
          }
        }
      };
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


    ferret_input.autocomplete({
      minLength: 2,
      source: ferret_choose.ontology_complete_url,
      cacheLength: 100,
      focus: function(event, ui) {
        return false;
      },
      select: function(event, ui) {
        ferret_choose.term_history = [trim(ferret_input.val())];
        ferret_choose.set_current_term(ui.item.id);
        ferret_choose.matching_synonym = ui.item.matching_synonym;
        return false;
      }
    })
    .data("autocomplete")._renderItem = function( ul, item ) {
      var search_string = $('#ferret-term-input').val();
      render_term_item(ul, item, search_string, ferret_choose.annotation_namespace);
    };

    function do_autocomplete () {
      ferret_input.focus();
      ferret_input.autocomplete('search');
    }

    ferret_input.bind('paste', function() {
      setTimeout(do_autocomplete, 10);
    });

    $('#ferret-test-do-search').click(function () {
      ferret_choose.term_selected($('#ferret-term-input').val());
    });

    ferret_input.keypress(function(event) {
      if (event.which == 13) {
        // return should autocomplete not submit the form
        event.preventDefault();
        ferret_input.autocomplete('search');
      }
    });

    $("body").delegate("#ferret-term-children-list a", "click",
                       ferret_choose.child_click_handler);
    $("body").delegate("#breadcrumbs .breadcrumbs-term a", "click",
                       ferret_choose.term_click_handler);
    $("body").delegate("#breadcrumbs-search a", "click",
                       ferret_choose.term_click_handler);

    $("#breadcrumb-previous-button").click(function () {
      ferret_choose.term_history.length -= 1;
      if (ferret_choose.term_history.length > 0) {
        if (ferret_choose.term_history.length == 1) {
          ferret_choose.set_current_term();
        } else {
          ferret_choose.set_current_term(last(ferret_choose.term_history));
        }
      } else {
        window.location.href = curs_root_uri;
      }
    });

    $('#ferret-term-input').attr('disabled', false);

    $('#ferret-suggest-link').click(ferret_choose.suggest_dialog);
    $('#ferret-suggest-link-leaf').click(ferret_choose.suggest_dialog);

    $("#ferret-suggest-form").validate({
      rules: {
        'ferret-suggest-name': "required",
        'ferret-suggest-definition': "required"
      },
      messages: {
        'ferret-suggest-name': "Please enter a name for the term",
        'ferret-suggest-definition': "Please enter a definition for the term"
      }
    });

    $("#curs-contact-form").validate({
      rules: {
        'curs-contact-name': "required",
        'curs-contact-definition': "required"
      },
      messages: {
        'curs-contact-name': "Please enter a name for the term",
        'curs-contact-definition': "Please enter a definition for the term"
      }
    });

    $('.pomcur-toggle-button').each(function (index, element) {
      var this_id = $(element).attr('id');
      var target = $('#' + this_id + '-target');
      $(element).click(
        function () {
          target.toggle()
        }
      );
      $(element).show();
    });

    $('.pomcur-more-button').each(function (index, element) {
      var this_id = $(element).attr('id');
      var target = $('#' + this_id + '-target');
      $(element).click(
        function () {
          target.show()
          $(element).hide();
          return false;
        }
      );
      $(element).show();
    });

    $(window).bind('hashchange', function(e) {
      var state = $.bbq.getState( this.id, true );
      var search_string = state.s;

      if (search_string) {
        if (state.c) {
          var crumbs = trim(state.c);
          var new_history = [search_string].concat(crumbs.split(","));
          ferret_choose.term_history = new_history
          $('#ferret-term-id').val(last(new_history));
        } else {
          ferret_choose.term_history = [search_string];
        }
      } else {
        ferret_choose.term_history = [];
      }

      $('#ferret-term-input').val(search_string);

      ferret_choose.render();
    })

    $(window).trigger( 'hashchange' );
  } else {

    $('#breadcrumb-previous-button').click(function () {
      window.location.href = curs_root_uri;
    });

  }

  $('input[type=checkbox]').shiftcheckbox();

  $('a.pomcur-select-all').click(function () {
    $(this).closest('div').find('input:checkbox').attr('checked', true);
  });

  $('a.pomcur-select-none').click(function () {
    $(this).closest('div').find('input:checkbox').removeAttr('checked');
  });

  $('#curs-finish-publication').click(function () {
    window.location.href = curs_root_uri + '/finish_form';
  });

  $('#curs-pause-publication').click(function () {
    window.location.href = curs_root_uri + '/pause_curation';
  });

  $('#curs-check-completed').click(function () {
    window.location.href = curs_root_uri + '/complete_approval';
  });

  $('#curs-cancel-approval').click(function () {
    window.location.href = curs_root_uri + '/cancel_approval';
  });

  $('#curs-stop-reviewing').click(function () {
    window.location.href = curs_root_uri + '/';
  });

  $('#curs-finish-gene').click(function () {
    window.location.href = curs_root_uri;
  });

  $('#curs-pub-assign-popup-dialog').click(function () {
    $('#curs-pub-assign-dialog').dialog({ modal: true,
                                          width: '50em' });
  });

  $('#curs-pub-triage-this-pub').click(function () {
    window.location.href = application_root + 'tools/triage?triage-return-pub-id=' + $(this).val();
  });

  $('#curs-pub-assign-cancel').click(function () {
    $('#curs-pub-assign-dialog').hide();
  });

  $('#pubmed-id-lookup-form').ajaxForm({
    dataType: 'json',
    beforeSubmit: function() {
      $('#pubmed-id-lookup-waiting .ajax-spinner').show();
    },
    success: function(data) {
      $('#pubmed-id-lookup-waiting .ajax-spinner').hide();
      if (data.pub) {
        $('#pub-details-uniquename').html(data.pub.uniquename);
        $('#pub-details-uniquename').data('pubmedid', data.pub.uniquename);
        $('#pub-details-title').html(data.pub.title);
        $('#pub-details-authors').html(data.pub.authors);
        $('#pub-details-abstract').html(data.pub.abstract);
        $('#pubmed-id-lookup').hide();
        $('#pubmed-id-lookup-message').hide();
        $('#pubmed-id-lookup-pub-results').show();
      } else {
        $('#pubmed-id-lookup-message').show();
        $('#pubmed-id-lookup-message span').html(data.message);
      }
    }
  });

  $('#pubmed-id-lookup-reset').click(function () {
    $('#pubmed-id-lookup-waiting .ajax-spinner').hide();
    $('#pubmed-id-lookup-pub-results').hide();
    $('#pubmed-id-lookup-input').val('');
    $('#pubmed-id-lookup').show();
  });

  $('#pubmed-id-lookup-curate').click(function () {
    var pubmedid = $('#pub-details-uniquename').data('pubmedid');
    var base = window.location.href.match(new RegExp('(http://[^/]+)/([^/]+)'));
    var bits = base.splice(1);
    if (bits[1] != 'tools') {
      bits.push('tools');
    }
    window.location.href = bits.join('/') + '/start/' + pubmedid;
  });

  $('.non-key-attribute').jTruncate({
    length: 300,
    minTrail: 50,
    moreText: "[show all]",
    lessText: "[hide]"
  });
});

// autocomplete for the traige tool
$(document).ready(function() {
  if (typeof curs_people_autocomplete_list != 'undefined') {
    $(".curs-person-picker .curs-person-picker-input").autocomplete({
      minLength: 0,
      source: curs_people_autocomplete_list,
      focus: function( event, ui ) {
        $(this).val( ui.item.name );
        return false;
      },
      select: function( event, ui ) {
        $(this).val( ui.item.name );
        $(this).siblings('.curs-person-picker-person-id').val( ui.item.value );
        return false;
      }
    })
    .data( "autocomplete" )._renderItem = function( ul, item ) {
      return $( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>" + item.label + "<br></a>" )
        .appendTo( ul );
    };
    $(".curs-person-picker button.curs-person-picker-add").click(function () {
      $(this).hide().siblings('div.curs-person-picker-add').show();
      $(this).siblings('.curs-person-picker-input').hide();
    });
  }
});

$(document).ready(function() {
  $(".confirm-delete").click(function(e) {
    e.preventDefault();
    var targetUrl = $(this).attr("href");

    var deleteDialog = $('#delete-dialog');
    if (deleteDialog.length == 0) {
      deleteDialog =
        $('<div id="delete-dialog" title="Confirmation needed">Really delete?</div>');
      $('body').append(deleteDialog);
    }
    deleteDialog.dialog({
      autoOpen: false,
      modal: true,
      buttons : {
        "Confirm" : function() {
          window.location.href = targetUrl;
        },
        "Cancel" : function() {
          $(this).dialog("close");
        }
      }
    });

    deleteDialog.dialog("open");
  });
});

var AlleleStuff = function($) {
  function add_allele_row($allele_table, data, $previous_row) {
    $allele_table.show();
    var name = data['name'];
    if (name == null) {
      name = 'noname';
    }
    var description = data['description'];
    if (description == null) {
      description = 'unknown';
    }
    var expression = data['expression']
    if (expression == null) {
      expression = 'null';
    }
    var conditions;
    if (typeof(data['conditions']) == 'undefined') {
      conditions = '';
    } else {
      conditions = data['conditions'].join(', ')
    }

    $('#curs-add-allele-proceed').show();

    var row_html =
      '<td>' + name + '</td>' +
      '<td>' + description + '</td>' +
      '<td>' + expression + '</td>' +
      '<td>' + data['evidence'] + '</td>' +
      '<td>' + conditions + '</td>' +
      '<td><img class="curs-allele-delete-row" src="' + delete_icon_uri + '"></td>' +
      '<td><a href="#" class="curs-allele-edit-row" id="curs-allele-edit-row-data-' + delete['id'] + '">edit&nbsp;...</a></td>';
    var $new_row = $('<tr>' + row_html + '</tr>');
    if (typeof($previous_row) == 'undefined') {
      $allele_table.find('tbody').append($new_row);
    } else {
      $previous_row.after($new_row);
    }
    $new_row.data('allele_id', data['id']);

    if ($.grep(existing_alleles_by_name,
               function(el) {
                 return el.value === name && el.description === description;
               }).length == 0) {
      existing_alleles_by_name.push({ value: name, description: description,
                                      display_name: data.display_name });
    }

    $new_row.data('allele_data', data);

    return $new_row;
  }

  function fetch_conditions(search, showChoices) {
    $.ajax({
      url: make_ontology_complete_url('phenotype_condition'),
      data: { term: search.term, def: 1, },
      dataType: "json",
      success: function(data) {
        var choices = $.map( data, function( item ) {
          return {
            label: item.name,
            value: item.name,
            definition: item.definition,
          }
        });
        showChoices(choices);
      },
    });
  };

  function make_condition_buttons($allele_dialog, $allele_table) {
    var used_conditions = {};
    $allele_table.find('tr').map(function(idx, el) {
      var el_allele_data = $(el).data('allele_data');
      if (typeof(el_allele_data) != 'undefined') {
        $.map(el_allele_data.conditions,
              function(cond, idx) {
                used_conditions[cond] = true;
              });
      }
    });
    var button_html = '';

    var used_buttons = $allele_dialog.find('.curs-allele-condition-buttons');

    used_buttons.find('button').remove();

    $.each(used_conditions,
           function(cond) {
             button_html += '<button class="ui-widget ui-state-default curs-allele-condition-button">' +
               cond + '</button>';
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

  function add_allele_confirm($allele_dialog, $allele_table) {
    var $form = $('#curs-allele-add form');
    var $orig_allele_row = $allele_dialog.data('edit_allele_row');
    if ($form.validate().form() || typeof($orig_allele_row) !== 'undefined') {
      $form.ajaxSubmit({
        dataType: 'json',
        success: function(data) {
          try {
            var $new_row = add_allele_row($allele_table, data, $orig_allele_row);
//          make_condition_buttons($allele_dialog, $allele_table);
            if (typeof($orig_allele_row) !== 'undefined') {
              $orig_allele_row.remove();
              remove_allele_row($orig_allele_row);
            }
            $new_row.effect("highlight", { color: "#aaf" }, 2500);
          } catch (err) {
            $allele_table.append($orig_allele_row);
          }
        },
      });
      $('#curs-allele-add .curs-allele-conditions').tagit("removeAll");
      var $reuse_checkbox = $form.find('input[name="curs-allele-reuse-dialog"]');
      if ($reuse_checkbox.is(':checked')) {
        $.pnotify({
          pnotify_title: 'Notice',
          pnotify_text: 'Allele successfully added',
        });
        $reuse_checkbox.attr('checked', false);
      } else {
        $allele_dialog.dialog("close");
      }
    }
  }

  function add_allele_cancel() {
    $(this).dialog("close");
  }

  function set_expression($allele_dialog, value) {
    var $expression_row = $allele_dialog.find('.curs-allele-expression');
    $expression_row.find('input[value="' + value + '"]').attr('checked', true);
  }

  function unset_expression($allele_dialog) {
    var $expression_row = $allele_dialog.find('.curs-allele-expression');
    $expression_row.find('input').attr('checked', false);
  }

  function hide_allele_description($allele_dialog) {
    $allele_dialog.find('.curs-allele-type-description').hide();
    $allele_dialog.find('.curs-allele-description-input').val('');
    $allele_dialog.find('.curs-allele-type-select').show();
    set_expression($allele_dialog, "Not specified");
    get_allele_evidence_select_jq($allele_dialog).val('');
    var name_input = get_allele_name_jq($allele_dialog);
    name_input.removeAttr('disabled');
    var label = $allele_dialog.find('.curs-allele-type-label');
    label.hide();
  };

  function maybe_autopopulate(allele_type_config, name_input) {
    if (typeof allele_type_config.autopopulate_name != 'undefined') {
      if (name_input.val().length == 0) {
        var new_name =
          allele_type_config.autopopulate_name.replace(/@@gene_name@@/, gene_display_name);
        name_input.val(new_name);
        return true;
      }
    }
    return false;
  }

  function setup_description($allele_dialog, selected_option) {
    var description = $allele_dialog.find('.curs-allele-type-description');
    description.show();
    var description_input = description.find('input');
    var selected_text = selected_option.text();
    var allele_type_config = allele_types[selected_text];
    var label = $allele_dialog.find('.curs-allele-type-label');
    if (allele_type_config.description_required == 1) {
      label.show();
      label.find('span').text(selected_text);
      var description_placeholder_text = allele_type_config.placeholder;
      if (allele_type_config.placeholder === '') {
        description_input.attr('placeholder', '');
      } else {
        description_input.attr('placeholder', description_placeholder_text);
      }
      description_input.removeAttr('disabled');
    } else {
      label.hide();
      description_input.attr('placeholder', selected_text);
      description_input.attr('disabled', true);
    }
    description_input.placeholder();

    var $expression_span = $allele_dialog.find('.curs-allele-expression');
    var $endogenous_input = $expression_span.find("input[value='Endogenous']");

    if (allele_type_config.allow_expression_change == 1) {
      $expression_span.show();
    } else {
      $expression_span.hide();
      $endogenous_input.attr('checked', false);
    }

    var $endogenous_div = $endogenous_input.parent('div');
    var $not_specified_div = $expression_span.find("input[value='Not specified']").parent('div');
    if (allele_type_config.name === 'wild type') {
      $endogenous_div.hide();
      $endogenous_input.attr('checked', false);
      $not_specified_div.hide();
      $not_specified_div.attr('checked', false);
    } else {
      $endogenous_div.show();
      $not_specified_div.show();
    }

    setup_allele_name($allele_dialog, allele_type_config);
  }

  function setup_allele_name($allele_dialog, allele_type_config) {
    var name_input = get_allele_name_jq($allele_dialog);

    if (typeof(allele_type_config) === 'undefined') {
      name_input.attr('placeholder', 'Allele name (optional)');
    } else {
      var autopopulated = maybe_autopopulate(allele_type_config, name_input);

      if (allele_type_config.allele_name_required == 1 && !autopopulated) {
        name_input.attr('placeholder', 'Allele name required');
      } else {
        name_input.attr('placeholder', 'Allele name (optional)');
      }

      if (autopopulated) {
        name_input.data('autopopulated_name', name_input.val());
      }
    }
  }

  function setup_allele_form_validate(add_allele_dialog) {
    add_allele_dialog.find('form').validate({
      rules: {
        'curs-allele-type': {
          required: true,
        },
        'curs-allele-name': {
          required: function() {
            var selected_text = get_allele_type_select_jq(add_allele_dialog).val();
            var allele_type_config = allele_types[selected_text];
            if (typeof(allele_type_config) == 'undefined') {
              return false;
            } else {
              return allele_type_config.allele_name_required == 1;
            }
          }
        },
        'curs-allele-description-input': {
          required: function() {
            var selected_text = get_allele_type_select_jq(add_allele_dialog).val();
            var allele_type_config = allele_types[selected_text];
            if (typeof(allele_type_config) == 'undefined') {
              return false;
            } else {
              return allele_type_config.description_required == 1;
            }
          }
        },
        'curs-allele-evidence-select': {
          required: true
        },
        'curs-allele-expression': {
          required: function() {
            var selected_text = get_allele_type_select_jq(add_allele_dialog).val();
            var allele_type_config = allele_types[selected_text];
            if (typeof(allele_type_config) == 'undefined') {
              return false;
            } else {
              return allele_type_config.allow_expression_change == 1;
            }
          }
        }
      }
    });
  }

  function remove_allele_row($tr) {
    var allele_id = $tr.data('allele_id');

    $.ajax({
      url: curs_root_uri + '/annotation/remove_allele_action/' + annotation_id +
        '/' + allele_id,
      cache: false,
    }).done(function() {
      if ($tr.closest('tbody').children('tr').size() == 1) {
        $tr.closest('table').hide();
        $('#curs-add-allele-proceed').hide();
      }
      $tr.remove();
    });
  }

  function get_allele_name_jq ($allele_dialog) {
    return $allele_dialog.find('.curs-allele-name');
  }
  function get_allele_desc_jq ($allele_dialog) {
    return $allele_dialog.find('.curs-allele-description-input');
  }
  function get_allele_type_select_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-type-select select')
  }
  function get_allele_type_label_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-type-label-span');
  }
  function get_allele_evidence_select_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-evidence-select');
  }
  function get_allele_expression_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-expression'); 
  }
  function get_allele_conditions_jq($allele_dialog) {
    return $allele_dialog.find('.curs-allele-conditions');
  }

  function populate_dialog_from_data($allele_dialog, data) {
    get_allele_name_jq($allele_dialog).val(data.name);
    get_allele_desc_jq($allele_dialog).val(data.description);
    get_allele_type_select_jq($allele_dialog).val('other').trigger('change');
    // big hack:
    get_allele_type_select_jq($allele_dialog).val(undefined);
    // another hack:
    get_allele_type_label_jq($allele_dialog).closest('tr').hide();
    get_allele_evidence_select_jq($allele_dialog).val(data.evidence);
    if ("expression" in data) {
      set_expression($allele_dialog, data.expression);
    } else {
      unset_expression($allele_dialog);
    }
    if ("conditions" in data) {
      $.map(data.conditions, function(item) {
        get_allele_conditions_jq($allele_dialog).tagit("createTag", item);
      });
    };
  }

  function init() {
    var $allele_dialog = $('#curs-allele-add');
    var $allele_table = $('#curs-allele-list');

    $($allele_table).on('click', '.curs-allele-delete-row', function (ev) {
      var $tr = $(this).closest('tr');
      remove_allele_row($tr);
    });

    $($allele_table).on('click', '.curs-allele-edit-row', function (ev) {
      var $tr = $(this).closest('tr');
      var allele_id = $tr.data('allele_id');
      add_allele_dialog.dialog("option", "buttons", edit_allele_buttons);
      add_allele_dialog.dialog("open");
      var allele_data = $tr.data('allele_data');
      populate_dialog_from_data($allele_dialog, allele_data);
      $(add_allele_dialog).data('edit_allele_row', $tr);
    });

    $('#curs-add-allele-details').click(function () {
      add_allele_dialog.dialog("option", "buttons", add_allele_buttons);
      add_allele_dialog.dialog("open");
      $(add_allele_dialog).removeData('allele_data');
      return false;
    });

    if (typeof(alleles_in_progress) != 'undefined') {
      $.each(alleles_in_progress,
             function(key, value) {
               add_allele_row($allele_table, value);
             });

      $('#curs-add-allele-proceed').click(function() {
        window.location.href = curs_root_uri + '/annotation/process_alleles/' + annotation_id;
      });
    }

    var add_allele_buttons = [
      {
        text: "Cancel",
        click: add_allele_cancel,
      },
      {
        text: "Add",
        click: function() {
          add_allele_confirm($allele_dialog, $allele_table);
        },
      },
    ];

    var edit_allele_buttons = [
      {
        text: "Cancel",
        click: add_allele_cancel,
      },
      {
        text: "Edit",
        click: function() {
          add_allele_confirm($allele_dialog, $allele_table);
        },
      },
    ];

    var add_allele_dialog = $allele_dialog.dialog({
      modal: true,
      autoOpen: false,
      height: 'auto',
      width: 600,
      title: 'Add an allele for this phenotype',
      buttons : add_allele_buttons,
      open: function() {
        $('#curs-allele-add .curs-allele-name').autocomplete({
          source: existing_alleles_by_name,
          select: function(event, ui) {
            var new_select_val = 'other';
            if (allele_types[ui.item.description] != undefined) {
              new_select_val = ui.item.description;
            }
            get_allele_type_select_jq($allele_dialog).val(new_select_val).trigger('change');
            get_allele_desc_jq($allele_dialog).val(ui.item.description).attr('disabled', true);
            var label = add_allele_dialog.find('.curs-allele-type-label');
            label.hide();
          }
        }).data("autocomplete" )._renderItem = function(ul, item) {
          return $( "<li></li>" )
            .data( "item.autocomplete", item )
            .append( "<a>" + item.display_name + "</a>" )
            .appendTo( ul );
        };

        make_condition_buttons($allele_dialog, $allele_table);

        hide_allele_description(add_allele_dialog);
        get_allele_type_select_jq(add_allele_dialog).val(undefined).trigger('change');
        add_allele_dialog.find('.curs-allele-name').val('');
        var name_input = add_allele_dialog.find('.curs-allele-name');
        name_input.attr('placeholder', 'Allele name (optional)');

        setup_allele_form_validate(add_allele_dialog);
      },
    });

    $('#curs-allele-add .curs-allele-conditions').tagit({
      minLength: 2,
      itemName: 'curs-allele-condition-names',
      allowSpaces: true,
      placeholderText: 'Type a condition ...',
      tagSource: fetch_conditions,
      autocompleteOptions: {
        focus: function(event, ui) {
          $('.curs-autocomplete-definition').remove();
          if (ui.item.definition != null) {
            var def =
              $('<div class="curs-autocomplete-definition"><h3>Definition</h3><div>' +
                ui.item.definition + '</div></div>');
	    def.addClass('ui-widget-content ui-autocomplete ui-corner-all')
	      .appendTo('body');
            var widget = $(this).autocomplete("widget");
            def.position({
              my: 'left top',
              at: 'right top',
              of: widget
            });
          }
        },
        close: function() {
          $('.curs-autocomplete-definition').remove();
        },
      },
    });

    $allele_dialog.on('click', '.curs-allele-description-delete', function () {
      var $button = $(this);
      hide_allele_description($allele_dialog);
      get_allele_type_select_jq($allele_dialog).val(undefined).trigger('change');
      var name_input = get_allele_name_jq($allele_dialog);
      if (typeof(name_input.data('autopopulated_name')) != 'undefined' &&
          name_input.val() === name_input.data('autopopulated_name')) {
        // clear the name if we created it
        name_input.val('');
      }
    });

    $allele_dialog.on('change', '.curs-allele-type-select select', function (ev) {
      var $this = $(this);
      $this.closest('tr').hide();
      var selected_option = $this.children('option[selected]');
      var name_input = get_allele_name_jq($allele_dialog);
      if (selected_option.val() === '') {
        hide_allele_description($allele_dialog);
        get_allele_expression_jq($allele_dialog).hide();
        var selected_text = selected_option.text();
        var allele_type_config = allele_types[selected_text];
        setup_allele_name($allele_dialog, allele_type_config);
        return;
      }
      setup_description($allele_dialog, selected_option);
    });
  }

  return {
    pageInit: init
  };
}($);
