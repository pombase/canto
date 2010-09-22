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

var pomcur = {
  ontology_complete_url : application_root + '/ws/lookup/go/component',

  term_history : [],

  use_term_data : function(data) {
    var term = data[0];

    $('#ferret-term-entry').val(term.name);
    $('#ferret-term-definition').text(term.definition);

    var children = term.children;
    var children_html = '';

    $.each(children, function(idx, child) {
      children_html += '<li><a href="#' + child.id + '">' + child.name + '</a></li>';
    });

    $('#ferret-term-children').data('child-count', children.length);
    $('#ferret-term-children-list').html($('<ul/>').append($(children_html)));
  },

  set_details : function(term_id) {
    $('#ferret-confirm').show();
    $('#ferret-term-children').hide();
    var stored_term_id = $('#ferret-term-id').val();
    if (stored_term_id != term_id) {
      $('#ferret-term-id').val(term_id);
    }
    $.ajax({
      url: pomcur.ontology_complete_url,
      data: { term: term_id, def: 1, children: 1 },
      dataType: 'json',
      success: pomcur.use_term_data
    });
  },

  term_selected : function() {
    var term_id = $('#ferret-term-id').val();
    if (term_id) {
      pomcur.set_details(term_id);
    }
  },

  set_term : function(term) {
    $('#ferret-term-id').val(term.id);
    $('#ferret-term-id-display').text(term.id);
    $('#ferret-term-entry').val(term.name);
    $('#ferret-term-details').show();
  },

  child_click_handler : function() {
    var href = $(this).attr('href');
    var term_id = href.substring(href.indexOf('#') + 1);
    pomcur.set_details(term_id);
  },

  show_hide_children : function() {
    var term_children = $('#ferret-term-children');
    if (term_children.data('child-count') > 0) {
      term_children.show();
    } else {
      term_children.hide();
    }
  },

  ferret_reset : function() {
    // from: http://stackoverflow.com/questions/680241/blank-out-a-form-with-jquery
    $(':input','#ferret-form')
      .not(':button, :submit, :reset, :hidden')
      .val('')
      .removeAttr('checked')
      .removeAttr('selected');
    $('#ferret-term-children').hide();
    $('#ferret-term-details').hide();
    return true;
  }
};


$(document).ready(function() {
  $( "#ferret-term-entry" ).autocomplete({
    minLength: 2,
    source: pomcur.ontology_complete_url,
    focus: function(event, ui) {
      $('#ferret-term-entry').val(ui.item.name);
      $('#ferret-confirm').hide();
      return false;
    },
    select: function(event, ui) {
      pomcur.set_term(ui.item);
      return false;
    },
    close: pomcur.term_selected
  })
  .data( "autocomplete" )._renderItem = function( ul, item ) {
    return $( "<li></li>" )
      .data( "item.autocomplete", item )
      .append( "<a>" + item.name + " <span class='term-id'>(" + item.id + ")</span></a>" )
      .appendTo( ul );
  };

  $("body").delegate("#ferret-term-children-list a", "click",
                     pomcur.child_click_handler);

  $("#ferret input[name='reset']").click(pomcur.ferret_reset);

  var form_success = function(responseText, statusText, xhr, $form) {
    if (responseText == 'term-selected') {
      $('#ferret-confirm').hide();
      pomcur.show_hide_children();
    }
    return true;
  };
  $('#ferret-form').ajaxForm({ success: form_success });
  $('#ferret-term-entry').attr('disabled', false);
});
