Array.prototype.last = function() {return this[this.length-1];}

$(document).ready(function() {
  $(".sect .sect-title").each(function(i) {
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

var ferret_choose = {
  term_history : [],

  initialise : function(current_component) {
    ferret_choose.ontology_complete_url =
      application_root + 'ws/lookup/go/' + current_component;
  },

  use_term_data : function(data) {
    var term = data[0];

    $('#ferret').data('current-term', term);

    $('.ferret-term-name').text(term.name);
    $('#ferret-term-definition').text(term.definition);

    if (term.comment) {
      $('#ferret-term-comment-row').show();
      $('#ferret-term-comment').html('<div class="term-comment">' +
                                     term.comment + '</div>');
    } else {
      $('#ferret-term-comment-row').hide();
      $('#ferret-term-comment').html('');
    }

    var children = term.children;
    var children_html = '';

    $.each(children, function(idx, child) {
      var img_html =
        '<img src="' + application_root + '/static/images/right_arrow.png"/>';
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

    ferret_choose.hide_accept();
  },

  get_stored_term_id : function() {
    return $('#ferret-term-id').val();
  },

  set_details : function(term_id) {
    ferret_choose.hide_children();
    var stored_term_id = ferret_choose.get_stored_term_id();
    if (stored_term_id != term_id) {
      $('#ferret-term-id').val(term_id);
    }
    $.ajax({
      url: ferret_choose.ontology_complete_url,
      data: { term: term_id, def: 1, children: 1 },
      dataType: 'json',
      success: ferret_choose.use_term_data,
      async: false
    });
    $('#ferret-term-entry').hide();
  },

  term_selected : function(term_id) {
    $('#ferret-term-id').val(term_id);
    $('.ferret-term-id-display').text(term_id);
    $('#ferret-term-details').show();

    ferret_choose.set_details(term_id);
  },

  add_to_breadcrumbs : function(term) {
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
    var div = $('<div class="hash-term"><a title="' +
               term.name + '" href="#' + term.id + '">' +
               term.id + "</a></div>");
    div.data('term', term);
    dest.append(div);
  },

  add_history : function(term) {
    ferret_choose.term_history.push(term);
  },

  truncate_history : function(term_id) {
    $('#breadcrumbs-search').remove();
    if (ferret_choose.term_history.length > 0) {
      var html = '<li id="breadcrumbs-search">Search</li>';
      $('#breadcrumbs ul').append(html);
    }
    for (var i = 0; i < ferret_choose.term_history.length; i++) {
      var this_term = ferret_choose.term_history[i];
      if (this_term.id == term_id) {
        ferret_choose.term_history.length = i;
        break;
      } else {
        ferret_choose.add_to_breadcrumbs(this_term);
      }
    };
  },

  pop_history : function() {
    var last_id = ferret_choose.term_history.last().id;
    ferret_choose.truncate_history(last_id);
    ferret_choose.term_selected(last_id);
    ferret_choose.show_hide_children();
    ferret_choose.hide_accept();
    return false;
  },

  ignore_children : function() {
    ferret_choose.hide_child_details();
    ferret_choose.show_accept();
    ferret_choose.hide_help();
    return false;
  },

  show_accept : function() {
    $('#ferret-accept-term-details').show();
  },

  hide_accept : function() {
    $('#ferret-accept-term-details').hide();
  },

  move_to_hash_term : function(link) {
    var href = link.attr('href');
    var term_id = href.substring(href.indexOf('#') + 1);
    ferret_choose.truncate_history(term_id);
    ferret_choose.term_selected(term_id);
  },

  term_click_handler : function(event) {
    ferret_choose.move_to_hash_term($(event.target));
    ferret_choose.hide_leaf();
    return false;
  },

  child_click_handler : function(event) {
    ferret_choose.add_history($('#ferret').data('current-term'));
    ferret_choose.move_to_hash_term($(event.target).closest('a'));
    return false;
  },

  current_child_count : function() {
    var term_children = $('#ferret-term-children');
    return term_children.data('child-count');
  },

  show_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.show();
    ferret_choose.hide_leaf();
    ferret_choose.show_help();
    ferret_choose.show_child_details();
  },

  hide_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.hide();
  },

  show_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.show();
    ferret_choose.hide_children();
    ferret_choose.show_help();
    ferret_choose.show_child_details();
  },

  hide_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.hide();
  },

  hide_child_details: function() {
    $('#ferret-children-details').hide();
  },

  show_child_details: function() {
    $('#ferret-children-details').show();
  },

  show_hide_children : function() {
    if (ferret_choose.current_child_count() > 0) {
      ferret_choose.show_children();
    } else {
      ferret_choose.hide_children();
    }
  },

  hide_help : function() {
    $('.inline-help').hide();
  },

  show_help : function() {
    $('.inline-help').show();
  },

  suggest_dialog : function() {
    $('#ferret-suggest-term-id').val($('#ferret-term-id').val());
    $('#ferret-suggest').dialog({ modal: true,
                                  title: 'Suggest a new term',
                                  width: 800 });
    return false;
  },

  ferret_reset : function() {
    // from: http://stackoverflow.com/questions/680241/blank-out-a-form-with-jquery
    $(':input','#ferret-form')
      .not(':button, :submit, :reset, :hidden')
      .val('')
      .removeAttr('checked')
      .removeAttr('selected');
    ferret_choose.hide_child_details();
    $('#ferret-term-details').hide();
    $('#ferret-term-entry').show();
    ferret_choose.hide_accept();
    $('#ferret-term-id').val('');
    ferret_choose.show_help();
    return true;
  }
};


var curs_home = {
  show_term_suggestion : function(term_ontid, name, definition) {
    var html = '<div> Term name:' +
      '<span class="term-name">' + name + '</span></div>' +
      'Definition: <div class="term-definition">' + definition +
      '</div></div>';
    $('#term-suggestion').html(html);
    $('#term-suggestion').dialog({ modal: true,
                                   title: 'Child term suggestion for ' +
                                     term_ontid});
  }
};

$(document).ready(function() {
  var ferret_input = $("#ferret-term-input");

  if (ferret_input.size()) {
    ferret_input.autocomplete({
      minLength: 2,
      source: ferret_choose.ontology_complete_url,
      focus: function(event, ui) {
        $('#ferret-term-input').val(ui.item.name);
        return false;
      },
      select: function(event, ui) {
        ferret_choose.term_selected(ui.item.id);
        return false;
      }
    })
    .data("autocomplete")._renderItem = function( ul, item ) {
      var search_string = $('#ferret-term-input').val();
      var search_bits = search_string.split(/\s+/);
      var match_name = item.name;
      for (var i = 0; i < search_bits.length; i++) {
        var bit = search_bits[i];
        if (bit.length > 0) {
          var re = new RegExp('(' + bit + ')', "gi");
          match_name = match_name.replace(re,'<b>$1</b>');
        }
      }
      return $( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>" + match_name + " <span class='term-id'>(" +
                 item.id + ")</span></a>" )
        .appendTo( ul );
    };

    ferret_input.keypress(function(event) {
      if (event.keyCode == '13') {
        event.preventDefault();
      }
    });

    $("body").delegate("#ferret-term-children-list a", "click",
                       ferret_choose.child_click_handler);
    $("body").delegate("#breadcrumbs .hash-term a", "click",
                       ferret_choose.term_click_handler);

    $("#breadcrumb-previous-button").click(function () {
      if (ferret_choose.term_history.length > 0) {
        ferret_choose.pop_history();
      } else {
        if ($('#ferret-term-id').val().length > 0) {
          ferret_choose.ferret_reset();
        } else {
          window.location.href = curs_root_path;
        }
      }
    });
    $("#ferret-ignore-children").click(ferret_choose.ignore_children);

    var form_success = function(responseText, statusText, xhr, $form) {
      if (responseText == 'term-selected') {
        ferret_choose.show_hide_children();
      }
      return true;
    };

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
  } else {

    $('#breadcrumb-previous-button').click(function () {
      window.location.href = curs_root_path;
    });

  }

});
