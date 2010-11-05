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

var ferrit_choose = {
  term_history : [],

  initialise : function(current_component) {
    ferrit_choose.ontology_complete_url =
      application_root + 'ws/lookup/go/' + current_component;
  },

  use_term_data : function(data) {
    var term = data[0];

    $('#ferret').data('current-term', term);

    $('#ferret-term-name').text(term.name);
    $('#ferret-term-definition').text(term.definition);

    if (term.comment) {
      $('#ferret-term-comment').html('Comment: <div class="term-comment">' +
                                     term.comment + '</div>');
    } else {
      $('#ferret-term-comment').html('');
    }

    var children = term.children;
    var children_html = '';

    $.each(children, function(idx, child) {
      children_html += '<li><a href="#' + child.id + '">' +
        '<img src="' + application_root + '/static/images/plus_box.png"/>' +
        child.name + '</a></li>';
    });

    $('#ferret-term-children').data('child-count', children.length);
    $('#ferret-term-children-list').html($('<ul/>').append($(children_html)));

    if (children.length == 0) {
      ferrit_choose.show_leaf();
    } else {
      ferrit_choose.show_children();
    }

    ferrit_choose.hide_accept();
  },

  get_stored_term_id : function() {
    return $('#ferret-term-id').val();
  },

  set_details : function(term_id) {
    ferrit_choose.hide_children();
    var stored_term_id = ferrit_choose.get_stored_term_id();
    if (stored_term_id != term_id) {
      $('#ferret-term-id').val(term_id);
    }
    $.ajax({
      url: ferrit_choose.ontology_complete_url,
      data: { term: term_id, def: 1, children: 1 },
      dataType: 'json',
      success: ferrit_choose.use_term_data,
      async: false
    });
    $('#ferret-term-entry').hide();
  },

  term_selected : function(term_id) {
    $('#ferret-term-id').val(term_id);
    $('.ferret-term-id-display').text(term_id);
    $('#ferret-term-details').show();

    if (ferrit_choose.term_history.length > 0) {
      $('#ferret-previous-button').show();
      $('#ferret-reset-button').hide();
    } else {
      $('#ferret-previous-button').hide();
      $('#ferret-reset-button').show();
    }
    ferrit_choose.set_details(term_id);
  },

  add_to_breadcrumbs : function(term) {
    var breadcrumbs_ul = $('#breadcrumbs ul')
    var li = $('<li class="hash-term">&gt;<a title="' +
               term.name + '" href="#' + term.id + '">' +
               term.id + "</a></li>");
    li.data('term', term);
    breadcrumbs_ul.append(li);
  },

  add_history : function(term) {
    ferrit_choose.term_history.push(term);
    ferrit_choose.add_to_breadcrumbs(term);
  },

  truncate_history : function(term_id) {
    $('#breadcrumbs li.hash-term').remove();
    for (var i = 0; i < ferrit_choose.term_history.length; i++) {
      var this_term = ferrit_choose.term_history[i];
      if (this_term.id == term_id) {
        ferrit_choose.term_history.length = i;
        break;
      } else {
        ferrit_choose.add_to_breadcrumbs(this_term);
      }
    };
  },

  pop_history : function() {
    var last_id = ferrit_choose.term_history.last().id;
    ferrit_choose.truncate_history(last_id);
    ferrit_choose.term_selected(last_id);
    ferrit_choose.show_hide_children();
    ferrit_choose.hide_accept();
    return false;
  },

  ignore_children : function() {
    ferrit_choose.hide_child_details();
    ferrit_choose.show_accept();
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
    ferrit_choose.truncate_history(term_id);
    ferrit_choose.term_selected(term_id);
  },

  term_click_handler : function(event) {
    ferrit_choose.move_to_hash_term($(event.target));
    ferrit_choose.hide_children();
    var leaf = $('#ferret-leaf');
    leaf.hide();
    return false;
  },

  child_click_handler : function(event) {
    ferrit_choose.add_history($('#ferret').data('current-term'));
    ferrit_choose.move_to_hash_term($(event.target));
    return false;
  },

  current_child_count : function() {
    var term_children = $('#ferret-term-children');
    return term_children.data('child-count');
  },

  show_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.show();
    ferrit_choose.hide_leaf();
    ferrit_choose.show_child_details();
  },

  hide_children : function() {
    var term_children = $('#ferret-term-children');
    term_children.hide();
  },

  show_leaf : function() {
    var leaf = $('#ferret-leaf');
    leaf.show();
    ferrit_choose.hide_children();
    ferrit_choose.show_child_details();
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
    if (ferrit_choose.current_child_count() > 0) {
      ferrit_choose.show_children();
    } else {
      ferrit_choose.hide_children();
    }
  },

  suggest_dialog : function() {
    $('#ferret-suggest-form').dialog({ modal: true,
                                       title: 'Suggest a new term' });
    return false;
  },

  ferret_reset : function() {
    // from: http://stackoverflow.com/questions/680241/blank-out-a-form-with-jquery
    $(':input','#ferret-form')
      .not(':button, :submit, :reset, :hidden')
      .val('')
      .removeAttr('checked')
      .removeAttr('selected');
    ferrit_choose.hide_child_details();
    $('#ferret-term-details').hide();
    $('#ferret-term-entry').show();
    ferrit_choose.hide_accept();
    return true;
  }
};


$(document).ready(function() {
  var ferret_input = $("#ferret-term-input");

  if (ferret_input.size()) {
    ferret_input.autocomplete({
      minLength: 2,
      source: ferrit_choose.ontology_complete_url,
      focus: function(event, ui) {
        $('#ferret-term-input').val(ui.item.name);
        return false;
      },
      select: function(event, ui) {
        ferrit_choose.term_selected(ui.item.id);
        return false;
      }
    })
    .data("autocomplete")._renderItem = function( ul, item ) {
      var search_string = $('#ferret-term-input').val();
      var search_bits = search_string.split(/\s+/);
      var match_name = item.name;
      for (var i = 0; i < search_bits.length; i++) {
        var re = new RegExp('(' + search_bits[i] + ')', "gi");
        match_name = match_name.replace(re,'<b>$1</b>');
      }
      return $( "<li></li>" )
        .data( "item.autocomplete", item )
        .append( "<a>" + match_name + " <span class='term-id'>(" + 
                 item.id + ")</span></a>" )
        .appendTo( ul );
    };
  }

  $("body").delegate("#ferret-term-children-list a", "click",
                     ferrit_choose.child_click_handler);
  $("body").delegate("#breadcrumbs li.hash-term a", "click",
                     ferrit_choose.term_click_handler);

  $("#ferret-reset-button").click(ferrit_choose.ferret_reset);
  $("#ferret-previous-button").click(ferrit_choose.pop_history);
  $("#ferret-ignore-children").click(ferrit_choose.ignore_children);

  var form_success = function(responseText, statusText, xhr, $form) {
    if (responseText == 'term-selected') {
      ferrit_choose.show_hide_children();
    }
    return true;
  };

  $('#ferret-term-input').attr('disabled', false);

  $('#ferret-suggest-link').click(ferrit_choose.suggest_dialog);
  $('#ferret-suggest-link-leaf').click(ferrit_choose.suggest_dialog);

});
